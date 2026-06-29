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

## RECOMMENDED STACK — Round 1 (preliminary; verify/expand each round)
| Layer | Candidate | License | Provenance verdict | Status |
|---|---|---|---|---|
| **Motion engine** | **Motion** (motion.dev / motiondivision/motion) | **MIT** | lift + build-vendor (vanilla `animate()`, no React lock-in) | ✅ [VERIFIED repo] — MIT, vanilla API, spring, hybrid WAAPI/GPU 120fps |
| Motion (React alt) | react-spring (pmndrs) | MIT | adapter if Goose UI is React | ✅ [VERIFIED repo] — spring-first, active v10.1.2 (2026-06-24, 29.1k★) |
| Pure-CSS motion | native CSS `linear()` spring easing | n/a (platform) | direct | ⏳ confirm WebKit support next round |
| **Component base** | LiqUIdify (HIG React) **vs** shadcn/ui + Apple tokens | LiqUIdify=? · shadcn=MIT | TBD | ⏳ [GAP] verify LiqUIdify license + WebKit; pick base |
| Design tokens | shadcn **Apple Design System** (SF Pro, Action Blue #0066cc, machine-readable DESIGN.md) | verify | reference/lift tokens | ⏳ [GAP] confirm terms |
| Glass (native) | `NSVisualEffectView` / macOS 26 Liquid Glass | Apple | platform | ✅ doctrine |
| Glass (web fallback) | frost+tint+specular CSS (NOT refraction) | n/a | clean-room CSS | ✅ refraction Chromium-only [VERIFIED prior] |
| Mobile-ish kits | Framework7 (MIT), Konsta UI | MIT | reference | ⏳ [GAP] iOS-leaning — assess macOS fit |

**Round-1 lead:** Motion is the confirmed motion engine (MIT, vanilla, spring, 120fps GPU). Component
base is the open decision — LiqUIdify (purpose-built HIG) is the front-runner but its **license is
unverified** (homepage only showed the title); shadcn/ui (MIT) + the Apple-token set is the safe fallback.

## COMPONENT MAPPING TABLE (skeleton — fill as Goose's live inventory is enumerated)
Status legend: ✅ VERIFIED (source + WebKit + A/B pixel-diff) · ⏳ GAP.
| Goose component | best web alt | license/provenance | WebKit | match recipe | spring values | A/B | status |
|---|---|---|---|---|---|---|---|
| Buttons | (LiqUIdify/shadcn) | — | — | SF Pro, 22–28px height, 6px radius, accent fill | press spring | — | ⏳ |
| Inputs / text fields | — | — | — | focus ring = system accent | — | — | ⏳ |
| Selects / dropdowns | — | — | — | macOS popup-button shape | present spring | — | ⏳ |
| Toggles / switches | — | — | — | macOS switch geometry | flip spring | — | ⏳ |
| Sliders | — | — | — | — | — | — | ⏳ |
| Tabs / segmented | — | — | — | macOS segmented control | slide spring | — | ⏳ |
| Sidebar / nav list | — | — | — | vibrancy blend | — | — | ⏳ |
| Chat bubbles | — | — | — | — | — | — | ⏳ |
| Message composer | — | — | — | — | — | — | ⏳ |
| Model/provider picker | (native exists — match it) | — | — | match the native Models picker | — | — | ⏳ |
| Modals / sheets | — | — | — | sheet present-dismiss | sheet spring | — | ⏳ |
| Popovers / tooltips / context menus | — | — | — | — | — | — | ⏳ |
| Toasts | — | — | — | — | slide+fade spring | — | ⏳ |
| Progress / spinners | — | — | — | — | — | — | ⏳ |
| Code blocks / tables | — | — | — | SF Mono | — | — | ⏳ |
| Settings forms | — | — | — | calm/fluid blended (not native) | — | — | ⏳ |
| Scroll areas | — | — | — | native momentum scrollbars | — | — | ⏳ |

## MOTION + PERF FINDINGS (Round 1)
- **Motion engine = Motion (MIT).** Vanilla `animate()` (framework-agnostic — works regardless of Goose's
  framework), real spring physics, "hybrid engine: JS + native browser APIs for 120fps GPU-accelerated."
  → primary for interactive/interruptible springs. Bundle size + explicit interruptibility = [GAP] next round.
- **react-spring (MIT, spring-first)** = the alt if Goose UI is React and we want hooks.
- **Pure CSS `linear()` springs** preferred where no JS interaction needed (cheaper) — confirm WebKit support.
- Perf budget (from doctrine): 60/120fps, animate transform/opacity ONLY (never layout props), virtualize the
  chat transcript + sessions list, bounded webview live-set + listener teardown. Instrument fps + input latency.

## VENDORING DECISIONS (ProvenanceGate — Round 1)
- Motion → **lift + build-vendor** (MIT, vanilla; vendor the `animate` core via the build-time bundle).
- shadcn tokens → **reference/lift** the DESIGN.md token values (colors/typography), our own CSS.
- Liquid Glass web libs → **clean-room CSS** (the frost+specular fallback; do NOT adopt the Chromium-only refraction).
- Native glass → platform (`NSVisualEffectView`/macOS 26).
- Component base → **DECISION DEFERRED** to Round 2 (pending LiqUIdify license + WebKit + Goose-framework check).

## GAP LIST → next rounds
1. **Enumerate Goose's LIVE component inventory** from the real Goose web-UI source (fill the table).
2. **Verify LiqUIdify license + WebKit + component list** (homepage was thin → fetch the repo/README).
3. Confirm **Goose UI framework** (React?) → decides LiqUIdify vs shadcn vs react-spring vs vanilla Motion.
4. Confirm shadcn Apple Design System terms + Framework7/Konsta macOS fit.
5. Verify **CSS `linear()` spring** WebKit support + Motion bundle size + interruptibility.
6. Connect + use the **HIG / SF Symbols / design-system MCP servers** (apple-dev-mcp, SF Symbols MCP).
7. **SF Symbols licensing** path (Apple-restricted) — system access vs SVG export vs MIT icon alt.
8. Build the **A/B pixel-diff harness** (native control vs web control) — required for any `[VERIFIED]`.

## INTEGRATION NOTES
- Build-time vendor via `build-tiptap-bundle.sh` model → `Resources/` → served via `WKURLSchemeHandler`. No runtime npm.
- Theme tokens injected as CSS vars (same mechanism as the editor theme injection).
- Webview transparent over a native `NSVisualEffectView` glass layer (doctrine).

## CHANGELOG
- 2026-06-29 R1: created. Verified Motion + react-spring (MIT, spring, active). Stack skeleton + gap list seeded.
  Component base + Goose inventory deferred to R2. (Goose plan change owned by the Plan-1 agent — not edited here.)
