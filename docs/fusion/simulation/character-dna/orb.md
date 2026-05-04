# Character DNA — Orb

> Body family: **Orb** (parameterized per DOCTRINE §5.1).
> Roughly square (~48×48). Used by the GPT Orchestrator preset
> and any Custom companion that picks Orb at the §6.1
> head_shape step.

This document is human-authored Character DNA per DOCTRINE §10.2.

---

## Identity

A circle / sphere that **drifts**. Calm, hovering, planner-feel.
The Orb does not walk — it slowly drifts (1-pixel ambient
motion in `idle`, 2-pixel motion in `walk`).

The Orb is the **conductor** archetype: it doesn't carry a
prop close to its body the way Block companions do. Instead,
when it has a prop selected, the prop floats *near* the orb at
arm's length (visually rendered as a separate sprite layer
with a small offset).

## Personality (animation direction)

| State | Personality |
| --- | --- |
| `idle` | 4-frame slow drift loop — orb floats ±1px vertically, slow breathing |
| `walk` | 8-frame drift across screen; orb does NOT bob (no legs to push off). It glides. |
| `think` | 6-frame inner-glow pulse — the eye region brightens then dims as if the orb is processing. |
| `speak` | 4-frame ring pulse — a 1-pixel ring of accent-color appears at the orb's perimeter then fades. |
| `tool` | 6-frame baton/lantern conducting motion — the prop floats around the orb in a small arc (4 of the 6 frames are actual motion; 2 are hold). |
| `spawn` | 5-frame radial materialisation — the orb appears as a 1-pixel dot, expands to 3px, 5px, 7px, then settles at full size. Stepped, not smoothed. |
| `handoff_give` | 8-frame slow lift of the scroll into the air, then the scroll detaches and drifts right. |
| `handoff_receive` | 6-frame catch — orb bobs once, the scroll pulls into the orb's volume. |
| `retrieve` | 6-frame inward gather — the eye region brightens, a thin gold ring contracts inward 2px → 0px. |
| `error` | 4-frame violent jitter — orb skips ±2px each frame (more violent than Block error). |
| `recover` | 6-frame slow re-stabilisation; orb settles back to center. |
| `success` | 4-frame celebratory ring — a 2-pixel concentric ring expands outward and fades. |
| `sleep` | 4-frame very slow breathing; orb shrinks 1px and returns. |
| `gate` | 2-frame "awaiting" pose — orb is still and the eye region is unusually bright. |

## Palette family

Orb is a **two-tone palette** with a strong eye/accent
distinction:

| Channel | Role | Notes |
| --- | --- | --- |
| **Body (B in mask)** | dominant fill | GPT neutral `#9C9C9C` for the GPT Orchestrator preset; Custom users pick |
| **Accent (G in mask)** | rim / pulse rings | bluish-grey `#7B95A8` — concentrated at the orb's perimeter |
| **Eye (R in mask)** | inner core / pulse | bright accent — the closed-eyes resting state, animated as pulse-ring source |

Orb has NO `arms` overlay (the orb has no arms by silhouette);
the §5.2 arms axis is rendered as floating accent dots when
`arms == .Long` (a Custom companion choice). For the GPT
Orchestrator preset, `arms = None`.

## Silhouette direction (original)

- Approximately circular pixel disc, 32px diameter at 1× scale,
  centered in a 48×48 quad. The pixel-perimeter follows a
  stepped circle (the canonical pixel-art circle pattern: each
  pixel either inside-or-outside, no anti-aliased edges, per
  I-16).
- The 32px-diameter circle leaves a 16px margin around the
  body for the pulse ring + accent overlays + breath room.
- Eye region: a 6×4 horizontal slot just above the orb's
  vertical center. The eye is "Closed" (the §5.2 Eye axis)
  by default for the GPT preset — a 1-pixel-tall horizontal
  slit.
- No legs, no antennae, no horns. The orb is unmistakably
  *only* a circle.

## Allowed inspirations

- Ancient hovering spheres in mythological / sci-fi imagery.
- 8-bit ball enemies (the "drifting circle" archetype).
- Crystal balls / scrying orbs.
- The Bauhaus circle counterpart to the Block's square.
- The Kimi CLI's circular variant — **direction only**, see
  forbidden below.

## Forbidden inspirations

- The OpenAI logo (the swirl/knot mark) — that is a different
  asset (smooth-vector provider icon, §10.7 / §10.4 smooth
  category) and is not a body silhouette.
- Verbatim Kimi orb mascot tracing. The Kimi CLI's orb is
  reference for "what a friendly orb companion can look like";
  we draw our own pixels.
- Pokémon Voltorb / Electrode (Nintendo IP, distinctive face
  pattern, recognisable trademark).
- Tamagotchi orb-pets (Bandai trademark per §10.1).

## Substitution policy

The V2 artist refines this against the §6.1 wizard's live
preview where the GPT Orchestrator is the canonical configuration
under test. Their refinement provenance must demonstrate the
artist's authorship (a hand-pixeling diff log in the
provenance.json).
