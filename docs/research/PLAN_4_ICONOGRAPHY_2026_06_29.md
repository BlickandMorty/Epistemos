# PLAN 4 — Theme-Canonical Monochrome Iconography (canonical spec) — 2026-06-29

> **STATUS: SAVED / NOT YET ACTIVE.** Owner brainstormed + locked the shape 2026-06-29; do NOT start until the owner
> says go. This is the detail home for `docs/prompts/PROMPT_PLAN_4_ICONS.md` (the lean paste prompt points here).
>
> **Relationship to Plan 3 (NO fork, NO contradiction):** Plan 3 already shipped the *honest brand-logo registry +
> render spine + call-site wiring* — deliberately WITHOUT vendoring real third-party brand assets and WITHOUT any
> fake vendor-asset claims (see `PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md`). **Plan 4 is the missing layer:**
> vendor REAL [lobe-icons](https://github.com/lobehub/lobe-icons) monochrome SVGs behind that exact spine, normalize
> every glyph to `currentColor`, and drive the color from per-theme tokens so brand logos are *canonical with each
> theme's palette*. Plan 4 **upgrades the spine; it does not replace or fork it.** When Plan 4 activates, Plan 3's
> "whole-app logos" build-order item is registry-complete and the **asset + tint layer transfers to Plan 4** (single
> owner — no double-ownership).

---

## §0 — OWNER DECISIONS (LOCKED 2026-06-29, do not relitigate)
1. **Lobe-ize anything coverable, app-wide** — not just models/providers. Any surface where a brand/tool/service/
   integration has a logo lobe-icons covers (engines, MCP servers, marketplace, connectors, skills, integrations,
   settings rows, landing buttons, GitHub, Hugging Face, cloud providers, …) gets the real icon.
2. **Monochrome ONLY — but THEMIFY, do not hardcode B&W.** Strip the color from *every* glyph (the already-mono ones
   included). An icon is never literally `#000`/`#fff`; its color comes from the **active theme's palette token**.
   Switch themes → every brand logo re-tints in lockstep (exactly like SF Symbols tint by role/state).
3. **Canonical per theme.** Each Epistemos theme defines the icon color(s). Parchment → its warm ink; dark → its
   off-white; Platinum/SSTHX → their palettes. The logos read as part of the theme, not foreign brand color.
4. **Opus → Claude Code mascot · Sonnet/Haiku → regular Claude.** Per-MODEL-TIER, not just per-provider.
5. **Build on the shipped spine** (`ProviderBrandLogo` / `ProviderLogoView` / `IntegrationBrandMark`); do not fork it.
6. **Honesty preserved** — keep Plan 3's no-fake-vendor-claims + no-runtime-download invariants. Vendored at build,
   nominative use, marks unaltered (mono-normalize = a uniform recolor, not a logo redesign).

## §1 — VERIFIED CURRENT STATE  [VERIFIED-CODE 2026-06-29]
- `Epistemos/Views/Shared/ProviderBrandLogo.swift` (167L) — `ProviderBrand` registry; maps model providers + local
  model families; render-safe SF Symbol fallbacks. **Today maps by PROVIDER, not by model tier** (so Opus vs Sonnet
  is not yet distinguished — §5 fixes this).
- `Epistemos/Views/Shared/ProviderLogoView.swift` (26L) — renders an asset-catalog image when present, else a symbol
  fallback. **This is the model-logo render chokepoint.**
- `Epistemos/Views/Shared/IntegrationBrandMark.swift` (315L) — the NON-model brand registry (`IntegrationBrandMarkView`).
  No runtime download path, no official vendor-asset claims. **This is the integration/tool render chokepoint.**
- `Epistemos/Assets.xcassets` — **18** `ProviderLogo*.imageset` entries already exist, incl. `ProviderLogoClaude`,
  **`ProviderLogoClaudeCode`** (← Opus mascot, already present), `ProviderLogoCodex`, `ProviderLogoApple`, `ProviderLogoAI21`, …
- Theme token source (Swift): `Epistemos/Theme/EpistemosTheme.swift` (+ `Epistemos/Theme/PlatinumTheme.swift`).
- Native Models picker: `Epistemos/Goose/GooseNativeModelsView.swift` (**Plan-1 territory** — Plan 4 must NOT
  restructure it; it auto-upgrades via `ProviderLogoView`).
- Goose web vendored in-app at `Epistemos/Goose/`; the editable token source is `…/goose/ui/desktop/src/theme/
  theme-tokens.ts` (verify the in-app vs `.research-clones/work/goose/` copy before editing — the app may ship a built
  bundle; confirm the live token path).
- **Chokepoint consequence:** because Extensions/Skills/arXiv/Browser/Meeting/connectors/landing already render through
  `IntegrationBrandMarkView`, and models through `ProviderLogoView`, upgrading those TWO render paths + the asset
  catalog + the theme tokens auto-upgrades nearly every call site **without touching other plans' views.**

## §2 — lobe-icons FACTS  [VERIFIED 2026-06-29, sources below]
- Real, **MIT-licensed** library; 1,500+ AI/LLM brand icons; static SVG/PNG/WebP; **no runtime deps.**
- Use the **static SVG** package (`@lobehub/icons-static-svg`) — raw SVGs, NOT the React component package. Vendor the
  SVGs at build; never import React at runtime (MAS-safe).
- Coverage confirmed: Claude/Anthropic, OpenAI (GPT, **Codex**, DALL·E), Google (Gemini, **Gemma**, PaLM), Meta/Llama,
  Qwen, DeepSeek, Mistral, **Hugging Face**, **GitHub**, + many providers/tools.
- **License/trademark:** library code MIT; brand logos remain their owners' trademarks. Nominative use (identifying a
  provider/tool) is standard. Keep marks unaltered apart from the uniform mono recolor. Pin the repo URL + a real SHA;
  record license + provenance in the vendor manifest (mirror the EdgeParse/MarkEdit vendoring discipline).
- **Claude Code mascot:** lobe-icons has Claude/Anthropic/Codex; a distinct *Claude Code mascot* is NOT confirmed in
  the set. Epistemos already ships `ProviderLogoClaudeCode.imageset` — prefer that asset for Opus; if it is a
  placeholder, source the real Claude Code mascot separately and mono-normalize it like the rest.

## §3 — THE MONO-NORMALIZE PIPELINE (build-time, deterministic, MAS-safe)
- A **build-time script** (NOT runtime) vendors the chosen lobe-icons SVGs and **normalizes every one to a single
  `fill="currentColor"` path**: strip hardcoded `fill`/`stroke`/gradients/`<style>` color, collapse to one path,
  set `fill="currentColor"`. Output → `Epistemos.app` asset catalog (template-rendering imagesets) + a web mirror
  for Goose.
- **Content-hash gated** like the tiptap bundle (`build-tiptap-bundle.sh` pattern) — unchanged manifest skips the
  re-vendor/normalize. NEVER spawn npm/node at app runtime (MAS sandbox + hardened runtime forbid it).
- **Asset catalog:** imagesets set to **template rendering** so SwiftUI tints them via `.foregroundStyle(...)`.
- **A few complex logos** (gradient/multi-path marks that turn to mush as one color) get a **hand-simplified mono
  silhouette** at vendor-time. Enumerate them; this is per-icon polish, not a blocker.
- Honesty: the manifest records source repo + SHA + license per icon. No runtime fetch; no "official"/"verified"
  vendor claim beyond "vendored from lobe-icons @ <sha>, MIT".

## §4 — THEME-CANONICAL TINTING (the two-token-sources rule, extended to icons)
- Add an **icon-color token set** to BOTH canonical theme sources (this is the only place color lives):
  - Swift: `Epistemos/Theme/EpistemosTheme.swift` — e.g. `iconInk` (idle), `iconActive` (selected → the theme accent,
    `#0066cc`-family per theme), `iconMuted` (disabled). Define per theme (light / dark / Platinum / parchment / SSTHX / …).
  - Web: the Goose `theme-tokens.ts` mirror — `--icon-ink`, `--icon-active`, `--icon-muted` with IDENTICAL values.
- Render: native `ProviderLogoView`/`IntegrationBrandMarkView` apply `.foregroundStyle(theme.iconInk)` (active state →
  `iconActive`); web uses `color: var(--icon-ink)` with `fill: currentColor` SVGs. **Theme switch re-tints every logo
  on both surfaces with zero per-icon work.**
- ⚠️ **Editing the two shared theme files is a CROSS-AGENT interface change (HARD GATE)** — coordinate before touching
  them (Plan 1 owns the Goose web; the Swift theme file is shared). Add tokens additively; do not restyle existing tokens.

## §5 — THE ICON MAP (model-TIER-aware)
- Extend `ProviderBrand`/`ProviderBrandLogo` from provider-only to **model-tier-aware** so a single Anthropic provider
  resolves different glyphs by tier:
  | Model tier | Asset |
  |---|---|
  | **Opus** | `ProviderLogoClaudeCode` (Claude Code mascot) |
  | Sonnet | `ProviderLogoClaude` |
  | Haiku | `ProviderLogoClaude` (mono) |
  | GPT / Codex | OpenAI · `ProviderLogoCodex` |
  | Gemini / Gemma | Google · Gemma |
  | (others) | their lobe-icons glyph |
- Keep the SF-Symbol fallback for any id with no real logo (preserves the render-safe contract). Every fallback that
  now HAS a real lobe-icon gets upgraded; the map stays the single source of truth.

## §6 — SURFACE INVENTORY (app-wide; most auto-upgrade via the 2 chokepoints)
- **Models:** `GooseNativeModelsView` (the ONE native route), model chips, chat/agent header → via `ProviderLogoView`.
- **Settings:** providers, API-key rows, `ExtensionsDetailView` (MCP servers, marketplace, best-of, connectors),
  `SkillsSettingsView`, browser-use Pro diagnostics → via `IntegrationBrandMarkView`.
- **Integrations/tools:** arXiv/Browser/Meeting headers, `CoworkConnectorDirectory`, `LandingFeatureButton`
  `integrationBrand` map, GitHub, Hugging Face (model-download UI).
- **Goose surface (Plan-1 web — PRIMARY for model/provider icons):** Goose's own model selector, provider rows,
  settings, and integration rows render through Goose's React UI (lucide + its own marks). Inject the vendored mono
  SVGs + the `--icon-ink` token into the Goose reskin so Goose's icons match the app. ⚠️ **Coordinated seam** —
  Plan 1 owns `Epistemos/Goose/*` web; Plan 4 supplies the SVG set + token, Plan 1 (or coordinated) wires the swap.
- **Mini-Goose-chat / note companion (the Tolaria surface):** the note-scoped Goose WebView panel embedded in the
  Epdoc editor (model badge in its header, provider/tool icons in its tool cards) gets the same vendored mono SVGs +
  `--icon-ink`. Because it is a Goose WebView, it inherits the Goose-surface treatment above — but name it explicitly
  so it is not missed. (Ownership of the panel itself = see the Note-Companion plan; Plan 4 only supplies its icons.)
- Any NEW call site renders through the spine views — never inline a one-off `Image(...)` for a brand.

## §7 — BOUNDARIES / NO-COLLISION (Plans 1/2/3 run concurrently)
- **Plan 4 OWNS:** the vendor+normalize pipeline & manifest, the vendored mono SVG assets (asset catalog + web mirror),
  the icon-color tokens (added to the shared theme sources — HARD GATE, coordinate), the model-tier map extension in
  `ProviderBrandLogo`, and the render upgrade inside `ProviderLogoView` + `IntegrationBrandMarkView`.
- **Plan 4 does NOT:** restructure `GooseNativeModelsView` or any other plan's view (it relies on the chokepoint
  auto-upgrade); fork `ProviderBrandLogo`/`IntegrationBrandMark`; add a runtime download; touch the graph (DO NOT TOUCH).
- **Sequencing:** best run when the other plans' surfaces are stable, OR under the build-lock + coordination protocol
  (a 4th concurrent xcodebuild on a 16 GB M2 Pro is the known crash risk — icon work is light but still claims the lock).

## §8 — MAS-SAFETY + HONESTY (non-negotiable)
- Static SVGs only; vendored at build; no subprocess/npm/node at runtime; no runtime logo fetch.
- Preserve Plan 3's honesty invariants: no fake "official/verified" vendor-asset claims; `CoworkConnectorDirectory`
  stays honest-state. The mono recolor is uniform theming, not a redesign that misrepresents a mark.
- License/provenance recorded in the vendor manifest (repo + SHA + MIT). Keychain/xcodegen/no-model-files rules apply.

## §9 — ACCEPTANCE BAR (PROVEN-DONE, not build-green)
1. Every app surface that names a brand lobe-icons covers renders a **real vendored mono glyph** (the 18 assets grow to
   full coverage); no brand left on a generic SF-Symbol fallback where a real logo exists.
2. **Every** glyph (incl. already-mono ones) is `currentColor` — none carries its own color.
3. **Theme switch re-tints all logos on BOTH native + Goose web** (live demo across light / dark / Platinum / parchment / SSTHX).
4. Opus shows the Claude Code mascot; Sonnet/Haiku show Claude — verified live in the Models picker.
5. A/B pixel-diff vs the native chrome stays within the doctrine bar; deeply-fluid, no jank.
6. Honesty intact (no fake vendor claims, no runtime fetch); license manifest present.
7. Zero test regressions. Witnessed live in-app (not just compiled).

## §10 — CODE-TO-LIFT / RESEARCH POINTERS
- Spine to extend: `ProviderBrandLogo.swift`, `ProviderLogoView.swift`, `IntegrationBrandMark.swift`.
- Pipeline pattern to mirror: `build-tiptap-bundle.sh` (content-hash gate) + the EdgeParse/MarkEdit vendor-with-SHA
  discipline. Theme tokens: `Epistemos/Theme/EpistemosTheme.swift` + Goose `theme-tokens.ts`.
- Canon to obey: `EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` (tokens/springs/glass, two-token-sources, graph-untouched),
  `PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md` (the spine it upgrades), `CLAUDE.md` (NON-NEGOTIABLE CONSTRAINTS).
- RESEARCH-FIRST: read before editing; verify current code/disk before asserting; tag `[VERIFIED-CODE]`.

## §11 — ANIMATION LAYER (optional; owner-requested 2026-06-29; feasibility VERIFIED)
**Can the marks animate? YES — but NOT as GIFs, and NOT from lobe-icons.** [VERIFIED 2026-06-29, primary sources]:
- **lobe-icons is STATIC-only** (SVG/PNG/WebP — no animated variants). Any animation is sourced/built separately.
- **GIF is the WRONG vehicle** — 256 colors, no smooth alpha, raster, and CANNOT be recolored per theme → it would
  **break the theme-canonical mono rule (§4)**. Do not ship brand marks as GIF.
- **Right vehicle = Lottie** (`lottie-ios`, Apache-2.0, native macOS, VECTOR): renders vector animation natively +
  supports runtime recolor via **Value Providers**, so an animated mark STAYS mono and re-tints from the `iconInk`/
  `iconActive` token exactly like the static ones. Web surface (Goose) = **animated SVG (SMIL/CSS)** with `currentColor`.
  Simple motion = **SwiftUI-driven** animation of the static mono mark (already how the Farm mascots breathe — Plan 5 /
  `CompanionAnimationState`).
- **Trademark caution:** animating a THIRD-PARTY mark (Claude / Claude Code / Codex / GPT) is a *modification* — more
  sensitive than static nominative use. Prefer the brand's OFFICIAL animated asset where it ships one; otherwise use
  SUBTLE native motion (pulse/shimmer/slow-rotate) on the static mono mark, not a full redraw. The safest fully-animated
  marks are the Epistemos COMPANION mascots (your own IP — already animating).
- **Scope (additive, gated — does NOT change the static mono core):** an `AnimatedBrandMark` that falls back to the
  static mono SVG when no animation exists; Lottie/SVG vendored at build (no runtime fetch); still tinted by the theme
  token (mono preserved); reduce-motion → static (Invariant I-14). Owner's candidates: Opus→Claude Code, Sonnet→Claude,
  Codex, GPT — animate ONLY via official assets or subtle native motion; static everywhere else.
- **MAS-safe:** Lottie (Apache-2.0) + animated SVG + SwiftUI are all sandbox-safe; vendored at build, no subprocess.
- **SOURCING + PER-MARK BUILD PLAN [VERIFIED 2026-06-29]:** real animated brand assets DO exist — but on third-party
  marketplaces (IconScout, LottieFiles) as community RECREATIONS under their own licenses (IconScout "Digital License",
  LottieFiles "Lottie Simple License"), NOT as official free brand-kit downloads from OpenAI/Anthropic. So each is a
  license + trademark decision (App Store sensitivity).
  **★ OWNER DECISION 2026-06-29 — take the VENDOR-LICENSED-LOTTIES path:** vendor real licensed brand animations where
  the marketplace license clearly permits app redistribution AND the brand's trademark policy permits an animated mark
  — but **flag EACH mark for owner approval before it ships** (do not auto-bundle a brand Lottie). Procedural/subtle
  motion for any mark without a clean licensed asset; companion mascots (own IP) fully custom + first. Per mark:
  - **Big brands w/ a clean licensed Lottie (OpenAI/ChatGPT, Gemini, …):** vendor a properly-licensed dotLottie/JSON
    (prefer free Lottie-Simple-License; OWNER approves the license + trademark for each before it ships).
  - **Marks WITHOUT a good/licensed asset (Claude Code mascot, niche providers):** AUTHOR procedurally — SwiftUI motion
    on the mono SVG (draw-on / pulse / shimmer / slow-rotate), or a hand-built Lottie via SVGator / Rive / Haiku
    Animator (all export Lottie). Subtle, mono-preserving, no third-party asset.
  - **Companion mascots (your OWN IP):** full custom animation, ZERO trademark risk — safest + richest to animate
    (already breathing via `CompanionAnimationState` — deepen it). **Build these FIRST** (no license gate).
  - **Format:** dotLottie (`.lottie`) is the modern compact form; `lottie-ios` renders it natively + runtime-tints it.
  - **OWNER GATE before shipping ANY third-party brand animation:** confirm the marketplace license permits app
    redistribution AND the brand's trademark policy permits an animated mark. When unsure → procedural/subtle motion only.

---
**Sources:** [lobe-icons (GitHub, MIT)](https://github.com/lobehub/lobe-icons) · [icon set](https://lobehub.com/icons) ·
[static-svg package](https://www.npmjs.com/package/@lobehub/icons-static-svg) · [Codex icon](https://lobehub.com/icons/codex)
