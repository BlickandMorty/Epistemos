# Character DNA — Block (Wide variant)

> Body family: **Block** (parameterized per DOCTRINE §5.1).
> Wide aspect (1.4:1, ~64×48). Used by the Claude Code worker
> preset. The user-supplied `claudecode-color.svg` is the
> reference visual for the *direction* — Epistemos ships an
> original drawing in the same direction (orange wide pixel
> block with multi-leg bottom notches, single antenna,
> negative-space eye cutouts).

This document is human-authored Character DNA per DOCTRINE §10.2.

---

## Identity

A wide, scholarly pixel block — a **bookend** that thinks. The
silhouette reads as **careful and editorial**. The §5.4 preset
table calls Claude Code worker "careful code worker" and that
is the entire animation direction.

`Block(Wide, Multi, Single, NegativeSpace)` per the §5.1
parameter table:

- aspect = Wide (1.4:1, ~64×48)
- legs = Multi (4 leg notches at the bottom)
- antennae = Single (top-right protrusion, ~3px tall)
- eye_treatment = NegativeSpace (transparent cutouts — the
  background shows through where the eyes go)

The character carries a **wrench** by default (code-affinity
prop). The single antenna catches a 1-frame gleam during
`success`.

## Personality (animation direction)

| State | Personality |
| --- | --- |
| `idle` | very slight 1-pixel side-to-side sway, slower than Compact (4 frames stretched). Reads as "patient, considered". |
| `walk` | 8-frame measured gait; the four leg notches alternate in pairs (1+3 / 2+4). Body rocks ~1px each step but less than Compact. |
| `think` | 6-frame head-tilt + antenna sway. Antenna swings 1px each frame as if catching wind. |
| `speak` | 4-frame eye-cutout brightness pulse — the negative-space eyes "flicker" because the background behind them shifts intensity. |
| `tool` | 6-frame wrench articulation. Body holds steady; wrench rises and rotates 8° each frame. |
| `spawn` | 5-frame top-down materialisation — the antenna appears first, then the body builds downward in 5 horizontal scanlines. |
| `handoff_give` | 8-frame slow-and-deliberate scroll-pass to the right. The scroll lifts higher than Compact's hand-off. |
| `handoff_receive` | 6-frame catch-and-bring-close. The scroll comes to rest tucked against the body. |
| `retrieve` | 6-frame "open-the-folder" gesture. Folder opens, body bends 1px forward, antenna leans in. |
| `error` | 4-frame ±1px shake; antenna shakes more violently than body (1.5× amplitude — visible as a 2px swing). |
| `recover` | 6-frame slow breath loop; antenna slowly returns to vertical. |
| `success` | 4-frame celebration — antenna gleam (1-frame flash on the antenna tip), body bobs up 2px. |
| `sleep` | 4-frame slow rise/fall. Antenna folds 1px to the right (resting). |
| `gate` | 2-frame asking-permission pose — body slightly forward, antenna tilts respectfully. |

## Palette family

The Wide Block is a **three-tone palette** (slightly richer than
Compact because the larger silhouette needs more visual breakup):

| Channel | Role | Notes |
| --- | --- | --- |
| **Body (B in mask)** | dominant warm orange | Claude warm `#D97757` |
| **Accent (G in mask)** | cream/amber bands | Claude cream `#FFF1E5` (~25% of body pixels) — the spine that runs vertically through the middle |
| **Eye (R in mask)** | NegativeSpace — punched-through alpha | rendered as `mask.a = 0` in the eye region; the renderer composites the deep-indigo theater background through the cutouts |

For Custom Wide Blocks, the eye channel can hold a fill color
instead of negative-space cutout (configurable at creation time
per §5.1 `eye_treatment` parameter).

## Silhouette direction (original)

- Outer rectangle ~64px wide × ~48px tall (Wide 1.4:1).
- Bottom edge has **four leg notches**, each ~6px wide × ~5px
  tall, evenly spaced. This multi-leg pattern is what
  distinguishes Wide from Compact. Each notch should read as a
  rounded foot, not a sharp peg.
- Top-right corner has a **single antenna** ~4px wide × ~6px
  tall, with a single-pixel cap. The antenna is integral to
  the body silhouette.
- Two **eye cutouts** centered horizontally, in the upper
  third. Each eye is a 5×4 transparent rectangle with rounded
  corners (1-pixel diagonal at each corner). The cutouts let
  the theater backdrop show through.
- The prop hangs in front of the body, slightly right of
  center.

## Allowed inspirations

- The user-supplied `claudecode-color.svg` mascot direction —
  the warm-orange wide pixel block with multi-leg bottom
  notches. Inspiration ONLY: we draw our own pixels following
  this direction.
- Bookends. The "scholarly cube on legs" archetype.
- Industrial cooling units (the wide-with-vents silhouette).
- Sci-fi consoles from 8-bit era games (the trustworthy-
  terminal feel).

## Forbidden inspirations

- Verbatim pixel-trace of the Claude Code mascot SVG. The SVG
  is reference material; we do NOT raster-convert it for the
  atlas. The procedural V1 atlas draws original silhouette
  lines following this DNA.
- Anthropic's Claude logo (the abstract A-shape) — different
  asset, different licensing posture; not a body silhouette.
- Tamagotchi pixel pets (Bandai trademark; see §10.1).
- The classic Macintosh "smiling mac" silhouette.
- The Apple //e profile.

## Substitution policy

When an artist refines the V2 atlas, they receive this DNA + the
V1 procedural atlas as a starting point. Their refined V2 atlas
must remain visually distinct from the user-supplied Claude Code
SVG (verifiable by side-by-side visual diff in the V2 atlas's
provenance.json).
