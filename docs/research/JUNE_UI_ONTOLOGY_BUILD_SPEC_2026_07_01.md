# June UI Ontology — build spec (make Epistemos's UI structurally = June)

> 🔴 **SUPERSEDED 2026-07-02 — DO NOT BUILD FROM THIS.** This was the operative spec for the "make the agent surface structurally = June" port, which FAILED across ~13 rounds. The agent surface is now **OpenChamber** (Pro base) + **June = theme + landing signatures + the MAS surface** (June minimal + goose in-process backend), with **goose + OpenCode** engines. June's component ontology is NO LONGER the agent-surface base — OpenChamber's is. KEEP this doc only for June's token/component study (still useful for the June THEME pass + the June MAS surface + landing bar/gradient). Canon: memory `project_ui_base_pivot_openchamber_2026_07_02` + `project_product_shape_agent_center_2026_07_02`.

> **READ THE NUANCE FIRST.** The goal is to get Epistemos's UI **as close to June as possible by adopting June's component
> ONTOLOGY** — the real *anatomy* of each component (its exact structure + CSS: the slight shadow, the fine border, the
> radius/padding, the frosted layering, the internal composition) — **ported from June's actual source (MIT).**
> This is NOT a token recolor of Goose's existing components, and it is NOT wiring June's UI to a backend.
> **The ONLY things that change from June's originals: fonts + the Epistemos theme palette.** Nothing else.
> **⛔ PURE JUNE — NO OPENCHAMBER (owner 2026-07-01).** EVERY component, style, and pattern comes from June. Do NOT pull
> anything from OpenChamber (or any other app) — not the diff view, not a command palette, nothing. It is 100% June-ness.
> (Ignore the OpenChamber sections of the referenced study docs — they are historical only.)

## WHY "reskin" is not enough — the ontological diff (the owner's own example)
Goose's message bar looks wrong not because of its *color* but because it's a **structurally different component**: a hard
1px box border. June's message bar is a *different anatomy* — a **soft, near-borderless box with a slight shadow + a fine
subtle border + generous radius + a frosted backdrop**. You cannot recolor Goose's box into June's box; you must **rebuild
the component with June's structure.** That structural port — done for each component — IS this task. "Ontology of the
button, not the backend."

## WHAT THIS IS / ISN'T
| ✅ DO | ❌ DON'T |
|---|---|
| Port June's REAL component structure + CSS (from its MIT source) into Epistemos's web UI | Recolor/tweak Goose's existing components ("reskin") and call it done |
| Match each component's anatomy: shadow, border, radius, padding, frosted layers, internal layout, states, motion | Change only design tokens on the wrong underlying shapes |
| Overlay Epistemos theme tokens + the pixel greeting font on the ported components | Wire June's UI to `agent_core` / rewire June's ~90 commands / port its streaming (that's the OTHER, unwanted plan) |
| Leave handlers as stubs OR lightly bound to whatever Epistemos already exposes | Vendor June's Tauri/cloud backend, accounts, Hermes, or any functional layer |
| Achieve visual + structural parity with June, side-by-side | Pixel-ize everything / invent a new look |

## METHOD — port the real thing, theme it
1. **Source of truth = June's actual code** (MIT, `https://github.com/open-software-network/os-june`). Port the real CSS +
   component structure; do not approximate from screenshots.
2. **Port component-by-component:** recreate each June component in Epistemos's web UI with June's exact CSS/structure
   (the classes, the DOM shape, the states). Keep June's `tokens.css` variable NAMES as the seam.
3. **Overlay the theme:** point June's `--brand` + the per-theme token blocks at **Epistemos tokens** (two-token-source
   with `EpistemosTheme.swift`), and swap the fonts (see below). June's `color-mix(--brand …)` math then recolors
   everything for free — classic-B&W + custom palettes included.
4. **Fonts:** drop June's 3 COMMERCIAL faces (ABC Diatype / Martina Plantijn / Berkeley Mono — never ship them). Map
   `--font-serif`/`--font-sans`/`--font-mono` → your **pixel greeting font** (greeting/section-labels ONLY) + a free sans
   (body) + a free mono. Everything else stays June's.

## THE COMPONENT ONTOLOGY (port these faithfully — real values below; full CSS in the June clone)
Anchor everything on June's token foundation first, then the components. (Exact values verified from source.)

### 0. Foundation tokens (`src/styles/tokens.css`) — port verbatim, then repoint colors to Epistemos
- **Radii:** xs 4 · sm 6 · md 8 · lg 10 · xl 14 · 2xl 18 · pill 999 · window 10 (macOS)
- **Shadows (the "slight shadow" DNA):** `--shadow-sm: 0 1px 2px oklch(24% .002 84.59 / 6%)` · `--shadow-md: 0 4px 12px …
  + 0 1px 2px …` · `--shadow-lg: 0 18px 40px …/10% + 0 2px 6px …/6%` · `--shadow-inset: 0 0 0 1px oklch(0 0 none / 4%)`
- **Motion:** `--ease-out cubic-bezier(.22,1,.36,1)` · `--ease-spring cubic-bezier(.32,.72,0,1)` · fast 100 / med 160 / slow 240ms
- **Borders:** soft `--border` / `--border-subtle` (NO hard 1px box rules on panels/inputs — this is the whole point)
- **Spacing scale, type scale** (11→30px): port as-is.

### 1. Message bar / composer  ← the owner's exemplar; get this exact
Source: `src/components/agent/composer/ComposerEditor.tsx` + `app.css` (`.agent-composer`, `.agent-composer-box`,
`.agent-composer-editor*`). The anatomy to reproduce:
- **Box:** `background: color-mix(in oklch, var(--card) 92%, transparent)` + **`backdrop-filter: saturate(140%) blur(36px)`**
  (the frosted layer) · **subtle border** (`--border-subtle`, darkens toward the focus-ring at ~40% on focus) · **`--shadow-md`**
  (the "slight shadow") · generous radius. NO hard box border.
- **Editor:** min-height ≈ `--control-lg` (~44px), max-height 200px, overflow-y auto, **top/bottom scroll-fade gradients**
  when content overflows; Tiptap plain-text; "Message …" placeholder.
- **Toolbar row (below editor):** attach (+), model picker, send button.
- **Focus state:** border shifts to focus-ring tone + `--shadow-md` — a *quiet* focus, never the chunky OS blue ring.

### 2. Segmented control (Chat/Voice/Meetings/Agent)  ← `src/components/ui/SegmentedControl.tsx` + `.segmented*`
- Container: inline-flex, gap 2px, height 30px, padding 3px, radius 6px, `background: var(--surface-subtle)`, muted text.
- **Indicator:** absolute, top/bottom 3px, radius 4px, `background: var(--card)`, `box-shadow: var(--shadow-sm)`,
  `transition: transform 120ms var(--ease-spring), width 120ms var(--ease-spring)`.
- Buttons: transparent until active, font-weight 500, `transition: color 100ms var(--ease-out)`.

### 3. Buttons / switch / select  ← `src/components/ui/{Switch,Select}.tsx` + `.btn*` in `app.css`
Port June's button radii/padding/state anatomy (soft, shadowed, no hard border). Switch = role="switch" + thumb. Select =
custom popover with **align-selected** positioning (lines the chosen row up with the trigger; falls back below/above).

### 4. Dialog / popover / tooltip  ← `Dialog.tsx`, `HoverTip.tsx` + `.dialog-*`, `.hover-tip*`
- Dialog: portal + centered card, radius `--r-xl`, `--shadow-lg`, subtle border; **scrim** =
  `color-mix(in oklch, var(--foreground) 12%, transparent)` + `saturate(140%) blur(8px)`; entry
  `dialog-card-in var(--t-med) var(--ease-spring)` (spring); focus trap + Esc.
- Tooltip: hover-intent debounce (150ms), smart flip, compact variant `hover-tip-pop … var(--ease-spring)`.

### 5. Cards / lists / notes-meetings chrome / transcript rows  ← `NoteEditor.tsx`, `NotePreview.tsx`, `.transcript-turn*`
- Tabbed card (Notes/Transcription via the SegmentedControl), transcript turn card (source icon 16×14, mm:ss–mm:ss meta,
  line-clamp + "Show more", hover-revealed copy with 1.6s success flash), surface-tint hover (no border).

### 6. Polish  ← `app.css` + `dot-spinner.css`
- **Scrollbar:** 4px, invisible at rest, 3-state opacity via `color-mix(--muted-foreground 30%→55%)`.
- **Focus ring:** `outline: 2px solid var(--focus-ring); outline-offset: 2px`; kill on `.note-title/.note-body` to avoid double rings.
- **Sidebar collapse:** single `@property --sidebar-w-current` animates the geometry.
- **Dot spinner:** 800ms, 4-dot stagger; reduced-motion → static.
- **Recording pill + waveform:** `GlobalRecorderPill.tsx` + `Waveform.tsx` (rAF meter, 7 bars).
- **Wordmark/icons:** `JuneWordmark.tsx` uses `currentColor + --brand` → the model for wiring your Plan-4 mono icons.

## WHERE IT APPLIES
The app's primary **web UI surface** (today: the Goose web surface / whatever renders the chat + note UI). Rebuild that
surface's components to June's ontology. This is a **front-end/component-layer** task — it touches CSS + component
structure only. It does NOT require the agent runtime, the MAS bridge, or any data wiring to look right.

## SCOPE OUT (explicitly do NOT do)
- Do NOT rewire June's ~90 Tauri commands, its Hermes WebSocket/streaming, accounts, billing, or model catalog.
- Do NOT make the ported UI *functional* against `agent_core` as part of this task — handlers stay stubs or bind to
  whatever Epistemos already exposes. Functionality is a **separate, later** effort. (A June-structured button that does
  nothing yet is the correct output of THIS task.)
- Do NOT ship June's commercial fonts. Do NOT pixel-ize beyond the greeting/section-labels.

## DONE BAR
Side-by-side with June, each ported component is **structurally faithful** — the message bar's slight-shadow + fine-border
+ frosted anatomy matches, the segmented control's spring indicator matches, the dialog scrim/spring matches — **but
rendered in the Epistemos palette (all themes incl. classic-B&W + custom) with the pixel greeting font.** No hard box
borders anywhere June uses soft shadow. No hardcoded June colors (rust/cream) — every color from a token.

## REFERENCES
- Component inventory + file:line map (5-round study): `JUNE_OPENCHAMBER_UI_ADOPTION_PLAN_2026_07_01.md`
- Raw token/palette/font extraction: `JUNE_OPENCHAMBER_DESIGN_STUDY_2026_07_01.md`
- June source (MIT): `https://github.com/open-software-network/os-june` — key files:
  `src/styles/tokens.css`, `src/styles/app.css`, `src/components/ui/{SegmentedControl,Switch,Select,Dialog,HoverTip,EmptyState}.tsx`,
  `src/components/agent/composer/ComposerEditor.tsx`, `src/components/note-editor/{NoteEditor,NotePreview}.tsx`,
  `src/components/recorder/{GlobalRecorderPill,Waveform}.tsx`, `src/components/brand/JuneWordmark.tsx`, `src/lib/brand.ts`.
- Epistemos theme seam to point tokens at: `EpistemosTheme.swift` + the Goose web `theme-tokens.ts` (two-token-source).
