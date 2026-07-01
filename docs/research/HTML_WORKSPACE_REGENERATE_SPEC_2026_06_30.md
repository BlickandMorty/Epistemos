# HTML Workspace — Regenerate: the "not-a-demo" spec (owner-locked 2026-06-30)

> Plan 2 item (1). Owner decided (2026-06-30): make regenerate the **FULL version** — genuinely robust (not a demo),
> pixel-minimal styled, **with preset action buttons**. Presets = **Layout + Add-a-thing + Vault-data** (owner
> EXCLUDED style presets). Build to this; flip `isLive: true` only when it's proven in a launched app.

## What exists today (verified in code)
Real pipeline already present in `Epistemos/Views/HTMLWorkspace/HTMLWorkspaceRegenerate{Surface,Preview}.swift` +
`HTMLWorkspaceGooseRegenerator.swift`: atomic full-surface replace (routes/assets swap atomically, omitted preserved),
`.regenerate` AI-provenance stamping, live streaming (`streamRegeneration` → `AsyncThrowingStream`), preview-before-apply.
**Gaps that make it feel like a demo:** (a) still `isLive:false` (unproven in-app); (b) primary UX still exposes
**"Copy Prompt" + manual paste** of the model response into a `TextEditor`; (c) revert is stubbed
(`reversibleSnapshotName: nil`); (d) plain SwiftUI, no pixel styling; (e) only one template (vault-search dashboard).

## 1. ROBUST — kill the demo feel
- **One-click, fully in-app.** The PRIMARY path is: type/choose intent → press one button → it **streams live** into the
  preview → user hits Apply. No copy-prompt, no manual paste as the default. Keep manual-paste only as a hidden/advanced
  fallback (or remove) — it must NOT be the front-and-center flow.
- **Reversible for real.** Wire `reversibleSnapshotName` to an actual named snapshot taken *before* apply, and add a
  visible **Revert** (undo last regenerate) that restores it. Reversibility is part of the contract, not a nil field.
- **Keep the good parts:** atomic replace, `.regenerate` provenance, streaming, preview-before-apply — all stay.
- **Honesty gate:** flip `isLive: true` in `HTMLWorkspaceCapabilityStatus` ONLY after it's proven end-to-end in a
  cold-launched app (intent → stream → preview → apply → revert all work). Until then it stays `isLive:false` with an
  honest note. No fake "done."

## 2. PIXEL-MINIMAL STYLING (per the nativeness canon — do NOT over-pixel)
Follow `project_design_nativeness_canon_2026_06_30` / `EPISTEMOS_NATIVENESS_DOCTRINE`: the surface is **Apple-native,
flat, borderless** as the base; **pixel-minimalism is LIMITED to fonts on section labels / preset-button captions +
small accents + palette** — NOT the whole UI, no pixel-art blocks. **Theme-aware, including classic = black-and-white**
(read the theme; never hardcode B&W). Replace the plain rounded-rect chrome with the flat token recipe already approved
for Goose (`GOOSE_FLAT_PIXEL_RESKIN_SPEC_2026_06_30.md`) so it matches the rest of the app.

## 3. PRESET ACTION BUTTONS (the "do more things" row)
A row/grid of flat, pixel-captioned preset buttons. **Each preset is DATA (a canned instruction template) that runs through
the SAME atomic + reversible + provenanced streaming regenerate pipeline** — presets add no new code path, they just
seed the prompt. Owner-selected families:
- **Layout presets** — reshape the whole surface: `Dashboard` · `Landing page` · `Docs page` · `Single-column article`.
- **Add-a-thing presets** — inject a component into the current surface (don't wipe it): `Add chart` · `Add search box` ·
  `Add table` · `Add nav`.
- **Vault-data presets** — wire REAL live vault data via the existing `HTMLWorkspaceDataFeed` (no fake data):
  `Notes → cards` · `Recent captures` · `Related notes`.
- ⛔ **NOT style presets** (owner excluded dark-mode/retro/etc. for now).
- Each preset press = one-click streaming regenerate → preview → apply → revertable. Presets that need vault data must use
  the opt-in vault feed and degrade honestly if the vault has nothing.

## 4. THE REAL VISION — an interactive workspace built from ANY context (owner 2026-06-30)
Regenerate is not "rewrite the page." It is **compose an interesting, INTERACTIVE space from whatever context the user
brings** — and the generated surface stays interactive (search boxes, filters, tabs, charts, clickable cards, live
data), not a static export.
- **Context sources it can pull from (READ-ONLY, real, no fake):** free-text intent · the current surface/selection ·
  a chosen note or folder · **vault** (search results + specific notes via the existing `HTMLWorkspaceDataFeed` /
  search index) · the knowledge **graph** (related/linked notes) · recent **captures / chats / meeting notes** ·
  provenance/claims. "Pull from other parts of the app" = wire these existing read paths into the workspace context;
  do NOT invent new data or fabricate results — degrade honestly when a source is empty.
- **Interactive output:** the space it builds can include working search/filter over vault data, charts bound to real
  data, tabbed/linked cards, nav between generated routes — a live mini-app, seeded from context, reversible and
  provenanced like everything else here. Preset buttons (§3) are shortcuts into this; free-form context is the general case.
- Everything still flows through the SAME atomic + reversible + `.regenerate`-provenance + streaming pipeline. Vault/graph
  reads use existing services — read-only, opt-in, honest.
- **DIRECT MANIPULATION — it must FEEL integrated (owner 2026-06-30):** provide a **notes sidebar** in/beside the
  workspace (loads notes + captures + vault search + graph items). The user can **grab a sidebar item and DRAG it into a
  section of the workspace** → that section loads that item's real context (note body, capture, search result, linked
  notes) and the surface re-renders with it wired in. Equally, the user can **pick/pull context from within the workspace
  itself** (an in-surface "add context" picker over the same sources). Drag-drop and in-workspace pick are first-class,
  alongside free-text intent and preset buttons — the whole thing should feel like one integrated space, not a prompt box.
  Dropped/picked context is added to the section as REAL data (honest, read-only), and the resulting change is atomic +
  reversible + provenanced like every other regenerate.

## ⛔ HARD GUARDRAIL — DO NOT TOUCH THE CODE EDITOR (owner 2026-06-30, "biggest issue before")
All of this work stays in the **regenerate / preview / data-feed / preset / interactive-context** layer of the HTML
Workspace. It must **NOT** modify, refactor, restyle, or destabilize the **code editor / Source lens** — MarkEdit /
CoreEditor / the L3 code chrome / the HTML Workspace *source panes* (which ride the MarkEdit/CoreEditor Source lane).
That surface was the biggest breakage source before; leave it alone. If a regenerate/workspace change would require
touching the code-editor code paths, STOP and flag it instead of proceeding. The interactive workspace changes the
*preview/rendered* space and its context wiring, never the code-editing engine.

## Proof bar (before calling it done)
Cold-launch the app → open an HTML Workspace → (a) one preset from each family produces a working surface via live stream;
(b) Apply persists; (c) Revert restores the prior surface; (d) provenance shows `.regenerate`; (e) styling is flat +
theme-aware (test classic B&W). Only then flip `isLive:true`.
