# Character DNA — Sage

> Body family: **Sage** (humanoid). Tall, ~48×64. Used by
> Custom companions only — no §5.4 provider preset selects
> Sage in v1.1+ (the v1.0 "Claude = Sage" mapping was retired
> per §5.1).

This document is human-authored Character DNA per DOCTRINE §10.2.

---

## Identity

A tall, humanoid pixel sprite — head, body, arms, legs as
discrete segments. The **deliberate**, **careful** archetype.
Unlike Block's chunky-cube feel and Orb's drifting-sphere feel,
Sage walks the ground deliberately and gestures with intent.

Sage is the *only* head shape that has a discrete head — Block's
top is integral to the body, Orb has no head at all. For Sage,
the head is a separate ~12×12 region above the ~36×52 body,
joined by a 2-pixel-wide neck.

## Personality (animation direction)

| State | Personality |
| --- | --- |
| `idle` | 4-frame slow breath — the head bobs ±1px and shoulders rise/fall. |
| `walk` | 8-frame discrete-step gait. Each leg lifts and plants on alternating frames; body bobs 2px each step. Slower than Block's brisk gait. |
| `think` | 6-frame "hand to chin" gesture — left arm rises, right arm rests; head tilts 1px. |
| `speak` | 4-frame mouth-region brightness pulse + small head nod. |
| `tool` | 6-frame two-handed prop articulation — both arms engage; the prop is held forward. |
| `spawn` | 5-frame entrance — sprite materialises foot-up over 5 horizontal scanlines. |
| `handoff_give` | 8-frame full-arm extension — the scroll passes ceremonially. |
| `handoff_receive` | 6-frame two-handed receipt — Sage takes the scroll with both arms. |
| `retrieve` | 6-frame "consult-the-tome" gesture — Sage opens a folder, looks down, head bows 1px. |
| `error` | 4-frame staggered shake — Sage is more "off-balance" than "shake". The head wobbles independently from the body. |
| `recover` | 6-frame regain-composure — Sage breathes deeply, shoulders rise + fall. |
| `success` | 4-frame raised-fist celebration — right arm rises 4px in 2 frames, holds 1 frame, returns. |
| `sleep` | 4-frame head-droop loop — the head tilts 1px down, body slumps slightly. |
| `gate` | 2-frame supplicant pose — both hands forward, palms up. |

## Palette family

Sage is a **three-tone palette** plus an optional skin-tone
override for the head region:

| Channel | Role | Notes |
| --- | --- | --- |
| **Body (B in mask)** | robe / clothing | user-pickable for Custom |
| **Accent (G in mask)** | belt / scroll-band / prop tint | secondary palette colour |
| **Eye (R in mask)** | eye highlights / face accent | provider eye color when applicable; user-pickable for Custom |

The head region (top 12×12) is **not** automatically tinted —
the Sage rig leaves the head in its mask grayscale so a future
"skin tone" axis (V3+) can override it without touching the
robe. For V1, the head fills with body colour by default.

## Silhouette direction (original)

- Total bounding box: ~48×64.
- Head: ~12px wide × ~12px tall, centered horizontally, at the
  top.
- Body: ~36px wide × ~36px tall, in the middle. Robe-style
  bottom edge with a slight flare (1 extra pixel each side).
- Two arms emerging from the body's upper edges. Each arm is
  ~3px wide × ~10px tall (hanging down at rest). Arms animate
  separately via the `overlays/arms/` layer.
- Two legs at the bottom: ~5px wide × ~10px tall, separated
  by 4px.
- The body has a **belt** (1-pixel horizontal accent stripe)
  at the body's vertical midpoint.

## Allowed inspirations

- Generic JRPG mage / scholar / monk silhouettes (the discrete
  head-body-arms-legs archetype).
- Bauhaus humanoid figure abstractions.
- Wizard / wanderer pixel-art conventions (8-bit RPG genre).
- Tarot Hermit illustrations (the careful staff-and-lamp
  archetype).

## Forbidden inspirations

- Nintendo / SNK / Capcom-specific pixel sprites — those are
  recognizable IP. Avoid Mario, Link, Geno, etc.
- Earthbound's NPC sprites (Nintendo IP).
- Specific D&D character art (Wizards of the Coast IP).
- Game-of-Thrones / LOTR / Wheel-of-Time character likenesses.
- Tamagotchi pixel pets (Bandai trademark per §10.1).

## Substitution policy

V2 artist refines this against the Custom preset wizard preview.
Sage is the most-customisable body family, so the V2 atlas
should expose explicit overlay slots for `head`, `arms`, `legs`,
`belt` so a future skin-tone / clothing-axis can swap pieces
independently.
