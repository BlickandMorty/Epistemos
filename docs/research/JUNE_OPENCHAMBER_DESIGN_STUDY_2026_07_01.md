# June + OpenChamber — design-token study (for Epistemos surface skins, 2026-07-01)

> Owner wants to borrow the LOOK of two MIT apps — **June** (→ Chat/home/Goose surface) and **OpenChamber** (→ the
> Work/OpenGUI surface) — retheme both to the **Epistemos palette + a pixel greeting font**, and pick-and-choose
> components. This is the grounded extraction from the actual cloned source (both MIT, code-safe to vendor).

## ⭐ THE KEY FINDING — they are the SAME warm-oklch color family (not two clashing looks)
Both apps use **oklch, warm, low-chroma "sand/cream" palettes with an orange/rust accent** (hue ~85). They diverge only
on **light-vs-dark default** and **typography philosophy** — NOT on color DNA. So mixing them is coherent, and dropping
the **Epistemos tokens + pixel greeting font** on top unifies them into one app trivially. (My earlier "two genuinely
different design languages" read was wrong once the tokens were extracted.)

## JUNE — extracted (`os-june`, MIT code)
- **Framework:** hand-rolled CSS (framework-free) with **oklch + `color-mix`** tokens + `framer-motion` for motion. Token
  files: `src/styles/tokens.css` (palette + fonts) + per-surface CSS (`app.css`, `meeting-hud.css`, `agent-hud.css`).
  → **Easiest to vendor into a WKWebView surface** (no Tailwind build needed; just CSS).
- **Palette (warm sand, LIGHT-first, hue 84.59):** light `--foreground oklch(27.24% .0015 84.59)`,
  `--primary oklch(34% .008 84.59)` (a warm near-black, NOT a bright rust), `--muted-foreground oklch(55.8% .0015 84.59)`,
  warm off-white background (`color-mix`); accent/rust reserved for brand moments (`--destructive oklch(57% .22 27)`).
  Dark theme mirrors it (`--foreground .985`, `--primary oklch(.86 .008 84.59)`). Very monochromatic-warm — close to your
  "classic B&W + token accent" idea already.
- **⚠️ FONTS = COMMERCIAL (do NOT ship):** sans **ABC Diatype**, serif **Martina Plantijn**, mono **Berkeley Mono** —
  all paid, bundled as `.woff2`. You're swapping to your **pixel greeting font + a free sans** anyway, so this is moot —
  but do NOT vendor June's font files. Replace the serif display with your pixel font; replace Berkeley Mono with a free
  mono (JetBrains Mono / IBM Plex Mono, OFL).
- **Icons:** no icon library — ~8 **bespoke inline `<svg>`**. (You use your own Plan-4 mono icons, not these.)
- **What to take:** the warm-flat **layout + components** — the message input bar, the **card-in-a-tinted-frame**, the
  **shared notes↔meetings chrome** (Notes/Transcription + preview/source toggle), the floating recording pill, the
  segmented mode switch. The editorial-serif feel → becomes your pixel-heading feel.

## OPENCHAMBER — extracted (`openchamber/openchamber`, MIT code)
- **Framework:** **React 19 + Tailwind v4 + class-variance-authority + tailwind-merge + next-themes** (shadcn-flavored).
  Design tokens in `packages/ui/src/styles/design-system.css` + `typography.css`. → Modern but **needs a Tailwind build**
  to vendor (heavier than June's plain CSS).
- **Palette (warm sand, DARK-first, oklch):** dark `--background oklch(.16 .01 30)` (#151313),
  `--foreground oklch(.85 .02 90)` (#cdccc3), **`--primary oklch(.77 .17 85)` (#edb449 golden-sand accent)**,
  `--muted #403E3C`, `--accent #343331`, `--border #393836`. Light mode is ALSO warm sand
  (`--background oklch(.97 .02 85)` "warm sand", `--primary oklch(.65 .2 55)` orange). Same family as June.
- **✅ FONTS = FREE (OFL) + all-monospace:** `--font-sans` AND `--font-mono` are BOTH mono — **IBM Plex Mono /
  JetBrains Mono / Fira Code**, with **Nerd Font** variants (`JetBrainsMono Nerd Font`). The whole UI is monospace →
  that's its **terminal/developer signature**, fitting for the Work/OpenGUI surface. All free to ship.
- **Icons:** no icon lib → **Nerd Font glyphs** (icons embedded in the mono font) + minimal SVG. Terminal-native.
- **What to take:** the **developer/terminal structure** — sidebar (sessions) + chat timeline + **inline diff-review**
  panel + "Open in Finder/Terminal/editor" affordances + the branchable/undo timeline UX + the all-mono density.

## SIDE-BY-SIDE
| | **June** → Chat/home/Goose | **OpenChamber** → Work/OpenGUI |
|---|---|---|
| Framework | hand-rolled CSS + framer-motion (easy vendor) | React19 + Tailwind v4 + CVA (needs build) |
| Default | light, warm, consumer/editorial | dark, warm, developer/terminal |
| Color space | oklch, warm sand hue ~85 | oklch, warm sand hue ~85/30 — **same family** |
| Fonts | serif+sans+mono, **COMMERCIAL — don't ship** | all-mono IBM Plex/JetBrains, **free OFL ✅** |
| Icons | ~8 bespoke SVG | Nerd Font glyphs |
| Take | input bar · card-in-frame · notes/meetings chrome · recording pill · mode switch | sidebar+timeline+diff layout · mono density · open-in affordances |

## THE EPISTEMOS RECIPE (how to make both "yours")
Both are token-driven, so re-skinning is a **variable remap**, not a rewrite:
1. **Colors →** replace every `--background/--foreground/--primary/--accent/--border/--muted…` with the **Epistemos
   tokens** (two-token-source: `EpistemosTheme.swift` + web `theme-tokens.ts`), so ALL palettes incl. classic-B&W +
   custom propagate. Both already oklch + warm, so your tokens slot straight in.
2. **Fonts →** your **pixel display font on the greeting/section-labels ONLY**; clean free sans for body; free mono
   (JetBrains/IBM Plex) for code. **Drop June's commercial fonts entirely.**
3. **Icons →** your **Plan-4 monochrome lobe-icons** (currentColor, theme-tinted) — not their icon sets.
4. **Motion →** keep it token/spring-driven; June's framer-motion values are a good reference for the calibrated springs.

## LICENSING (verified)
- **Code:** both **MIT** — real components/CSS are vendorable with attribution. ✅
- **June fonts:** **commercial (ABC Diatype / Martina Plantijn / Berkeley Mono) — DO NOT ship.** Swap to pixel + free.
- **OpenChamber fonts:** IBM Plex Mono / JetBrains Mono = **OFL, free to ship.** ✅

## RECOMMENDATION
- **Work / OpenGUI ← OpenChamber:** take its terminal structure (sidebar + timeline + diff) + all-mono density; keep its
  free mono; retheme to Epistemos tokens. Its Tailwind stack is heavier to vendor — decide direct-vendor vs rebuild-in-your-stack.
- **Chat / home / Goose ← June:** take its warm-flat layout + the input bar / card-frame / notes-meetings chrome; its
  framework-free CSS is the **easiest to vendor**; retheme to Epistemos tokens; pixel greeting; drop the commercial fonts.
- **Unifier:** one Epistemos token layer + one pixel greeting font across BOTH → they read as one app, per-surface flavor.
