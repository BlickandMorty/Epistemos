# Goose reskin spec — clean flat + slight pixel twist (OWNER-APPROVED 2026-06-30)

> **Paste this to the Goose reskin agent (Plan 1).** The owner approved this exact look via a live mockup. **Retheme
> Goose's OWN web components** (shadcn/Radix/Tailwind + framer-motion) — do NOT replace them, do NOT build a native nav
> rail. Canon: `docs/research/EPISTEMOS_NATIVENESS_DOCTRINE_2026_06_29.md` (the 2026-06-30 OWNER REFINEMENT).

## The approved look
A **clean, Claude-desktop-style FLAT UI** + a **SLIGHT pixel-art twist**, inside the **native rounded window**.
Premium-flat, calm, generous whitespace, monochrome icons, one theme accent. Reference: it should feel like the Claude
Code desktop app — *not* boxy, *not* retro-pixel-everything.

## HARD RULES

1. **FLAT + BORDERLESS.** No thick outlines, no hard box borders, no 1px rules on panels / buttons / lists / cards /
   inputs. Differentiate surfaces ONLY by: a subtle background tint (surface levels) + spacing + at most a *very soft*
   shadow. The only hairline allowed is the native window edge.

2. **NO UGLY FOCUS OUTLINE (owner-flagged).** Kill the default focus ring/outline on the message input and on all
   inputs/buttons (the chunky blue OS ring). Replace it with a QUIET, theme-toned state — e.g.
   `box-shadow: inset 0 0 0 1px var(--border-muted)` or a soft `var(--surface-0)` fill shift — never a 2px hard outline.
   Keep a faint focus indicator for accessibility, but it must be subtle and theme-toned, never the blue ring.

3. **PIXEL TWIST — SLIGHT, HEADINGS ONLY.** Use the pixel display font ONLY on: the greeting heading, the section labels
   (`CHATS`, `COMPANIONS`, etc.), the window title, and the companion mascots. **Everything else stays clean SF Pro
   sans** — do NOT pixel-ize body text, buttons, inputs, icons, or chrome. It's a flavor accent, not a retro theme.

4. **NATIVE FRAME KEPT.** The rounded-corner window + vibrancy + traffic-lights + the calibrated springs stay (the
   "curved-white" window the owner likes). **NO native nav rail** — Goose's own rethemed web sidebar is the navigation.

5. **TOTAL THEME-AWARENESS — including a true BLACK-AND-WHITE mode.** Every color comes from the Epistemos tokens
   (two-token-sources: `EpistemosTheme.swift` + Goose `theme-tokens.ts`, in lock-step). **In the B&W / monochrome theme,
   EVERYTHING is grayscale — the accent TOO** (New-session chip, send button, active row, focus tint all become mono,
   ZERO blue). In colored + custom themes, the accent + tints come from that theme. **NEVER hardcode `#0066cc` or any
   color** — always read the token, so B&W stays B&W and the custom palette propagates everywhere.

6. **OPTIMIZED.** Keep it CSS-token-only and cheap — no heavy re-renders, no per-click reloads (the lag came from the
   now-cut native rail; don't reintroduce churn). It must feel instant.

## CONCRETE — what to change in Goose's web UI
- **Strip decorative borders:** in `ui/desktop/src/styles/main.css` + `theme-tokens.ts`, set component borders to
  transparent/none where they're decorative; separate surfaces by surface-tint + spacing instead.
- **Focus override:** global `:focus-visible` + the composer input lose the chunky outline; apply the quiet inset/tint
  treatment above, token-driven.
- **Surfaces:** panels/cards = a surface token + radius, no border; hover/active rows = a subtle surface-tint, not a border.
- **Pixel font:** load the pixel display font once; apply ONLY to the greeting / section-label / window-title / companion
  classes. (The native side already uses a pixel display font for the greeting/clock — match it.)
- **Accent:** every accent use → the `--accent` token; that token resolves to grayscale in the B&W theme and to the
  theme/custom color otherwise. Audit for any hardcoded blue and replace with the token.
- **Springs:** keep framer-motion tuned to the verified SwiftUI spring values.

## DO NOT
- Re-add thick borders/outlines or the blue focus ring.
- Hardcode blue (or any) color — it breaks the B&W mode and the custom palette.
- Pixel-ize everything — it's a *slight* twist (headings/labels/companions only).
- Replace Goose's components, or build/keep a native nav rail.

## VERIFY (prove each in the live app)
- Click the message input → NO chunky outline, just a quiet theme-toned focus.
- Switch to the B&W theme → ZERO blue anywhere (accent, focus, active states all grayscale).
- Switch to a colored / custom theme → accent + tints follow it live.
- Compare to the approved mockup: flat, borderless, pixel only on headings/labels/companions, native rounded window.
