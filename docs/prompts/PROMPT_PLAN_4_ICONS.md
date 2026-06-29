# PLAN 4 — Theme-Canonical Monochrome Iconography build prompt (SAVED — paste later)

> 🛑 **SAVED / NOT YET ACTIVE (owner 2026-06-29).** Do NOT launch this until the owner says go. Drafted to the same
> strictness as Plan 1/2/3 and parked. It UPGRADES the already-shipped brand-logo spine (Plan 3) — it does not fork it.
> FULL verified detail (current code, lobe-icons facts, pipeline, per-theme tokens, icon map, acceptance bar):
> **docs/research/PLAN_4_ICONOGRAPHY_2026_06_29.md** — READ IT FIRST; this paste is lean.

---

```
[$thermo-nuclear-code-quality-review](/Users/jojo/.codex/skills/thermo-nuclear-code-quality-review/SKILL.md)

★ LOOP MODE — NEVER STOP until I (the owner) type "stop". Continuous loop, not a one-shot. Work the build order item by item; after each, immediately continue. When the order is complete, DO NOT declare "done" and DO NOT idle — keep looping: (a) full-app thermonuclear pass + fix, (b) harden the weakest icon/theme path, (c) extend coverage to the next uncovered brand surface, (d) re-verify everything still green, repeat. Only the owner's "stop" ends it. Commit at every clean point.

WORK MODE — DEEP CODE, NOT TEST VOLUME: primary activity each cycle = deep code review + edge-case hardening of the real icon/render/theme code paths (run the thermonuclear skill as the main loop). Write a test ONLY to lock a specific bug you just fixed — no coverage-padding suites.

You are building PLAN 4 = theme-canonical MONOCHROME iconography, app-wide. Vendor REAL lobe-icons mono SVGs behind the EXISTING brand-logo spine, normalize every glyph to `currentColor`, and drive color from per-theme tokens so brand logos are canonical with each theme's palette. UPGRADE the spine; do NOT fork it. Deeply hardened, contradiction-free, nothing lost.

READ FIRST (the PLAN doc wins on conflict):
  - docs/research/PLAN_4_ICONOGRAPHY_2026_06_29.md  (THE plan — §0 owner decisions, §1 verified state, §3 pipeline, §4 tokens, §5 icon map, §7 boundaries, §9 acceptance)
  - docs/research/PLAN_3_WHOLE_APP_LOGOS_CODEPACK_2026_06_28.md  (the shipped spine you upgrade — do NOT fork ProviderBrandLogo/IntegrationBrandMark)
  - docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md  (two-token-sources, springs, graph DO NOT TOUCH, A/B bar)
  - Project rules: CLAUDE.md (NON-NEGOTIABLE CONSTRAINTS — esp. NO subprocess/npm at runtime on the MAS path; keys in Keychain; @Observable; never block @MainActor). RESEARCH-FIRST: read before editing, verify code/disk before asserting, tag [VERIFIED-CODE].

OWNER DECISIONS (LOCKED 2026-06-29 — do not relitigate; full text §0):
  - Lobe-ize ANYTHING coverable, app-wide (models, providers, engines, MCP, marketplace, connectors, skills, integrations, GitHub, Hugging Face, settings rows, landing buttons) — not just models/providers.
  - MONOCHROME only, but THEMIFY — strip color from EVERY glyph (already-mono ones too); color comes from the active theme's token, never hardcoded #000/#fff. Theme switch re-tints every logo.
  - Canonical per theme (light/dark/Platinum/parchment/SSTHX each define the icon color).
  - Opus → ProviderLogoClaudeCode (mascot, asset already exists) · Sonnet/Haiku → ProviderLogoClaude. Per-MODEL-TIER, not just provider.
  - Build ON the shipped spine; preserve Plan 3's honesty (no fake vendor claims, no runtime download).

★ NATIVENESS + UNIFIED LOOK (BINDING — detail in EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md; this paste is lean):
  - Mono brand glyphs ARE the native choice (SF-Symbols-style single-color, theme-tinted). Same vendored SVGs render in native chrome AND Goose web → one iconographic language, both surfaces.
  - Non-negotiables: two-token-sources (icon tokens live in EpistemosTheme.swift + Goose theme-tokens.ts, no third source) · deeply-fluid ProMotion + MINIMAL · A/B pixel-diff = the bar · GRAPH = DO NOT TOUCH · SF Symbols stay native-only (fallbacks) · CODE-RESEARCH (real openable code, in-repo first) + RESEARCH-BETWEEN-IMPLEMENTATION (read before edit, exhaustive, no-contradiction/preserve-nuance/break-nothing).

BUILD ORDER (per the plan; if an item already exists, verify/harden instead of rebuild):
  (1) Vendor pipeline — build-time script pins lobe-icons (@lobehub/icons-static-svg) repo+SHA, vendors chosen SVGs, NORMALIZES each to a single fill="currentColor" path, emits template-rendering imagesets + a Goose web mirror; content-hash gated like build-tiptap-bundle.sh; license/provenance manifest. NO runtime npm/node.
  (2) Theme tokens — add iconInk/iconActive/iconMuted to EpistemosTheme.swift + identical --icon-ink/active/muted to Goose theme-tokens.ts (HARD GATE: shared files — coordinate; additive only).
  (3) Render upgrade — ProviderLogoView + IntegrationBrandMarkView tint via .foregroundStyle(theme.iconInk)/color:var(--icon-ink); call sites auto-upgrade through these two chokepoints.
  (4) Icon map — extend ProviderBrandLogo to model-TIER-aware (Opus→ClaudeCode, Sonnet/Haiku→Claude); upgrade every fallback that now has a real glyph; keep SF-Symbol fallback for the uncovered.
  (5) Coverage sweep — every coverable brand surface (Settings/Extensions/Skills/connectors/arXiv/Browser/Meeting/landing/Goose web) renders a real mono glyph; a few gradient-heavy logos get a hand-simplified mono silhouette.
  (6) Opus mascot — if ProviderLogoClaudeCode is a placeholder, source the real Claude Code mascot + mono-normalize.

HARD GATES / FORBIDDEN:
  × Any npm/node/subprocess or runtime logo download on ANY path (vendor at build only; MAS sandbox forbids runtime spawn).
  × A glyph that carries its own color (everything = currentColor) OR a hardcoded #000/#fff icon color (must be a theme token).
  × Forking ProviderBrandLogo/IntegrationBrandMark, or restructuring GooseNativeModelsView or any other plan's view (rely on the chokepoint auto-upgrade).
  × Editing the two shared theme files WITHOUT coordinating (cross-agent HARD GATE; additive tokens only).
  × A fake "official/verified" vendor-asset claim; breaking CoworkConnectorDirectory honest-state.
  × Touching the graph (DO NOT TOUCH); keys in UserDefaults (Keychain only); editing .xcodeproj (xcodegen only); committing model files.
  × Build-green ≠ done. PROVEN-DONE: real mono glyph live in-app · all currentColor · theme switch re-tints both native+web · Opus=ClaudeCode/Sonnet=Claude verified in the picker · A/B within bar · license manifest present · zero regressions · witnessed live (Swift Testing @Test compile-verify + manual run; headless app-hosted runs crash-loop, push logic to pure helpers).

PARALLELISM / NO-COLLISION (Plans 1/2/3 may build concurrently):
  - You OWN: the vendor+normalize pipeline & manifest, the vendored mono SVG assets (asset catalog + web mirror), the icon-color tokens (shared theme files — coordinate), the model-tier map in ProviderBrandLogo, and the render upgrade inside ProviderLogoView + IntegrationBrandMarkView.
  - Do NOT touch: Epistemos/Goose/* views (Plan 1) beyond the theme-token mirror (coordinate) · Plan-2 editor surfaces · Plan-3 capability logic. You upgrade the SPINE + assets + tokens; the views auto-inherit.
  - BUILD-LOCK: a 4th concurrent xcodebuild on a 16 GB M2 Pro is the known crash risk — claim the build-lock before compiling; do non-build work (vendor/normalize/research) while it's held.

Commit at clean points (main-only, never lose work). When unsure, RESEARCH-FIRST then act. Stop only when I say stop; after the build order is complete with PROVEN-DONE evidence, keep looping through full-app thermo passes, weakest-path hardening, coverage extension, and re-verification.
```
