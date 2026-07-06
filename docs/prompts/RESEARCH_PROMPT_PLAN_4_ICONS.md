# DEEP-RESEARCH PROMPT — PLAN 4: ICONOGRAPHY (app + engine + feature + mascot marks)

**ID:** `EPI-RP-04-SIGILRY` · **Codename:** SIGILRY · Obey `RESEARCH_PROMPT_STANDARD.md` §3 rubric + §4 sources + §5 shape + §7 fabric (deep integration is graded).

> Paste below `─── BEGIN ───` into a deep-research model. Output = build-ready dossier. Owner
> authored 2026-07-06. **Build split: both builds (MAS + 1Code)** — but the *mascot* body-parts +
> accessories + emote badges this system produces are consumed most heavily by the 1Code-only
> Companion (Plan 5), so coordinate with Plan 5's D4b art-quality work.

─── BEGIN RESEARCH BRIEF ───

## 0. Who you are / deliverable
Principal design-systems researcher for a **macOS-native** app. Produce a build-ready **icon &
mascot-art system** dossier: the full mark inventory, the production art pipeline, the theming
model, and the fix for the current demo-grade visual artifacts. External primary sources only
(Apple HIG/SF Symbols, SVG/PDF vector, Lottie/Rive docs, real design systems). Cite everything;
invent nothing. Design against the file names below.

## 1. Product context (ground truth)
Epistemos is a macOS-native PKM whose look is **high-quality FLAT · MINIMAL · THEME-AWARE**: keep
the Apple-native window frame (rounded, vibrancy, traffic-lights, calibrated springs); surfaces are
flat + borderless (subtle tint + spacing + soft shadow, NO thick outlines, NOT the old thick-outline
pixel-art look, NOT glass-on-everything). **Total theme-awareness:** every mark must read correctly
across Classic / Ember / Platinum **and a user CUSTOM palette**, in light and dark — no hardcoded
color; marks read design tokens. Doctrine: `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md`.

The marks appear across: the app icon; the **agent engine chips** (Claude, Codex, GLM, Kimi, etc.);
**provider/model** marks; **per-feature** marks (Notes, Graph, arXiv, ResearchHub, Data, Browser,
Quick Capture, Voice); the **pill nav**; and — critically — the **tamagotchi mascot**: its body
parts, swappable accessories, and **emote badges** bound to real agent states.

## 2. Thesis
**One coherent, token-driven mono mark language that scales from a 16pt menu glyph to a lovable,
riggable mascot — flat, minimal, totally theme-aware, and free of the artifacts that make the
current mascots look like a demo.**

## 3. Hard constraints
1. **Total theme-awareness** — every mark derives color from tokens (incl. custom palette), light +
   dark. No hardcoded hex. Two token sources (native + web/editor) in lock-step.
2. **Flat/minimal/native** — matches the doctrine; not pixel-art, not glassy, not skeuomorphic.
3. **Native + WebView parity** — a mark/mascot must look identical whether rendered by SwiftUI
   (native surfaces) or in a WebView (1Code/Epdoc). Define how.
4. **MAS-safe** — no runtime asset fetch that violates sandbox; no forbidden dependencies.
5. **Artifact-free** — the mascot composition (layered body-parts + accessories) must not exhibit
   seams, sub-pixel misalignment, transform-origin drift, occlusion bugs, or HiDPI jaggies.

## 4. What exists today (extend, don't reinvent)
- Provider/brand marks: `Epistemos/Assets.xcassets/ProviderLogo*` imagesets (Claude, Codex, Apple,
  DeepSeek, Falcon, AI21, …) + the view that renders them + `IntegrationBrandMarkView`-class usage.
- Landing "Farm" mascots: `Epistemos/Views/Landing/Farm/` (`CompanionAvatarGlyph.swift`,
  `CompanionView.swift`) + `Epistemos/Views/Landing/PixelSurfaceComponents.swift` — this is where
  the **demo-grade artifacts** live today.
- Theme tokens: the Epistemos theme system (Classic/Ember/Platinum + custom), `AppDisplayTypography`,
  the oklch/token pipeline shared with the editor/web.
- Companion art needs: Plan 5 `RESEARCH_PROMPT_PLAN_5_COMPANION.md` §D4/D4b/D10 (emote states,
  motion-with-meaning, embodied editing).

## 5. Research dimensions
### D1 — The mark inventory & grid
- Enumerate every mark class and its sizes/states: app icon (incl. macOS "squircle" + menu-bar
  template), engine chips, provider/model marks, feature marks, pill-nav marks, status/emote badges.
- The **construction grid / keyline system** (à la SF Symbols / Material) for consistent weight,
  optical sizing, and alignment across 16–512pt. Cite Apple HIG + SF Symbols custom-symbol guidance.

### D2 — Native + WebView parity & format
- Verdict on format per surface: **SF Symbols custom** vs **PDF/SVG vector** vs **template images**
  for native; **inline SVG** for WebView. How to author once and render identically both places
  (shared SVG source → SF Symbol export? token-driven SVG?). Cite the real export/tooling paths.

### D3 — Theming model (the token binding)
- Exactly how a mark takes color from the active theme incl. the custom palette, in light/dark,
  without hardcoding. Monochrome/template tinting vs multi-token marks. How the native token source
  and the web/editor token source stay in lock-step. Contrast/accessibility across all palettes.

### D4 — The mascot art & rig system (the demo-fix — go deep, ties Plan 5 D4b)
- The **composable creature pipeline**: layered body-parts + swappable accessories (hats/eyes/
  mouths/held-items) with correct anchoring, z-order, scale, and identity. Verdict: layered
  vector/SVG vs sprite-sheet vs **Lottie** vs **Rive** (riggable, state-bound, lively). Weigh cost,
  MAS-sandbox safety, native-vs-WebView, and the "alive but not annoying" motion budget.
- **Root-cause + fix the current artifact classes** (seams, sub-pixel/anti-alias, transform-origin
  drift, accessory occlusion, HiDPI scaling) with concrete remedies.
- The **emote/pose set** bound to real agent states (idle/thinking/reading/editing/tool/await-
  approval/done/blocked) — the badge/pose vocabulary Plan 5 consumes. And the **accessory/
  customization catalog** the Plan 5 creation flow offers, guaranteed artifact-free in combination.

### D5 — App icon & system marks
- The macOS app icon (squircle, resolution set, dark/tinted variants for recent macOS), menu-bar
  template icon, Dock behaviors. Cite current Apple icon requirements/sizes.

### D6 — Delivery & tooling
- How marks are stored/generated/validated (asset catalog structure, a source-of-truth vector set,
  a lint that catches hardcoded color / missing size / bad contrast). Automate parity + theming
  checks so a mark can't regress silently.

## 6. Primary-source discipline
Cite Apple HIG, SF Symbols docs, current app-icon size specs, Lottie/Rive docs. Flag version-gated
macOS icon features. No invented tooling capabilities.

## 7. Deliverable
1. Executive thesis + one-look mark language. 2. Full mark inventory + grid (D1). 3. Native/WebView
parity + format verdict (D2). 4. Theming/token binding (D3). 5. **Mascot art & rig system + artifact
fixes + emote/accessory catalog** (D4 — headline section, ties Plan 5). 6. App icon & system marks
(D5). 7. Tooling + validation (D6). 8. Phased build order (token binding → base mark set → parity →
mascot rig/artifact-fix → emote catalog → app icon), each with a witnessable proven-done bar; flag
Plan 5 coordination. 9. Open questions.

## 8. Anti-patterns
No pixel-art/glassy/skeuomorphic marks. No hardcoded color. No native/WebView divergence. Don't ship
a mascot system that still artifacts. Don't duplicate Plan 5's companion logic — you own the *art*,
Plan 5 owns the *behavior*; define the seam.

─── END RESEARCH BRIEF ───
