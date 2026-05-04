# Character DNA — Hermes Snake

> Body family: **Snake** (Hermes-only; separate atlas) per
> DOCTRINE §5.1. Not in the Block/Orb/Sage taxonomy. Coiling,
> hovering, scholarly serpent.

This document is human-authored Character DNA per DOCTRINE §10.2.

---

## Identity

A coiled serpent / caduceus. Hermes is **the graph faculty**
(§8.1) — it does not stand on the ground, does not walk; it
**hovers, drifts, and slithers** between graph nodes. The
silhouette signature is "intelligent serpent that reads".

The Hermes Snake is rendered above the graph plane (z+1 per
§4.1) and never shares ground space with worker companions.
This DNA establishes the silhouette and motion vocabulary; the
concrete pixel pattern follows below.

The static **landing-ritual** version of Hermes uses canonical
NousResearch SVG art (or Epistemos-fallback per §8.2.1
substitution allowance — see `Epistemos/Hermes/`). The
**simulation-theater** atlas (this DNA's domain) is a separately
drawn original that takes inspiration from the canonical
landing visuals but is its own art asset per §8.2.3:

> "The snake (landing-page version) uses the canonical
> NousResearch SVG. The simulation-theater snake uses the
> redrawn-original atlas/hermes_snake.png; the canonical
> landing SVG is the visual reference for the redrawn atlas,
> not its source."

## Personality (animation direction)

| State | Personality |
| --- | --- |
| `idle` | 4-frame slow vertical drift. The serpent hovers and rotates 1px each frame around its center. |
| `walk` | 8-frame slither — the serpent's body undulates in a sine wave; head leads, tail follows. The hover height is constant; only the body wave moves. |
| `think` | 6-frame coil-tighten — the serpent contracts toward its center 1px each frame, then releases. |
| `speak` | 4-frame head-bob — the serpent's head bobs up 1px, down 1px, hold, return. |
| `tool` | 6-frame "consult-the-scroll" — the serpent's tail wraps around an imagined node (renders as a small accent ring at tail tip). |
| `spawn` | 5-frame radial coil-in — the serpent appears as a single dot, expands to a small spiral, then unfurls into the full coil. |
| `handoff_give` | 8-frame slow extension — the serpent's body uncoils 4px to the right as it passes a node off. |
| `handoff_receive` | 6-frame coil-back — the serpent re-coils and tightens around the received item. |
| `retrieve` | 6-frame "graph-coil" — the serpent's tail pulls a node closer (visualised as a 2px gold ring contracting at the tail). |
| `error` | 4-frame chaotic swirl — the serpent's coil temporarily breaks into 4 disconnected segments, then reforms. |
| `recover` | 6-frame slow re-coiling — the segments find each other and rejoin. |
| `success` | 4-frame triumphant lift — the serpent rises 4px in 2 frames, holds 1 frame, returns. The accent gold ring at head pulses. |
| `sleep` | 4-frame slow contraction — the serpent's coil tightens to the smallest circle, breathes once, returns. |
| `gate` | 2-frame "guardian" pose — the serpent's head rises slightly, body forms a defensive S-curve. |

## Palette family

Hermes Snake is a **gold-bronze three-tone**:

| Channel | Role | Notes |
| --- | --- | --- |
| **Body (B in mask)** | dominant gold | hermes gold `#D4AF37` (the §10.7 brand colour) |
| **Accent (G in mask)** | bronze stripe / scale highlight | bronze `#A07028` |
| **Eye (R in mask)** | eye gleam | bright yellow `#FFCC00` (matching the canonical wordmark primary) |

Hermes is the only preset where the §6.1 wizard does NOT allow
palette override — the gold/bronze identity is fixed by §5.4
("Hermes Faculty: gold / orange / bronze"). Custom companions
that pick `HermesSnake` head shape are blocked by the wizard
(the §6.2 contrast gate accepts the user's hex but the wizard
warns that Hermes head is reserved for the canonical preset).

## Silhouette direction (original)

- Total bounding box: ~64×48 (Wide aspect, like Block Wide,
  but a different silhouette).
- The snake renders as a **3-coil spiral** in `idle` — three
  loops, each ~12px diameter, stacked vertically with 2-pixel
  gaps. The head emerges at the top-right; the tail at the
  bottom-left.
- The head: ~6px wide × ~6px tall, oriented to the upper
  right. Two `Slit` eyes (the §5.4 Hermes preset eye style)
  rendered as 1×3 horizontal slits each.
- No legs (the snake hovers — §4.1 z+1).
- The body is segmented every 4 pixels with a 1-pixel-darker
  bronze stripe (the accent channel). This is the "coiled
  caduceus" silhouette read.

## Allowed inspirations

- The mythological caduceus (the Hermes staff with twin
  serpents). For the V1 atlas we render **one** serpent (single
  spirit) — V2+ may add the twin caduceus variant.
- Ouroboros imagery (the snake-eating-its-tail loop).
- 8-bit JRPG snake enemies (the spiral-coil archetype).
- The canonical NousResearch caduceus SVG — **direction
  reference only** (we draw our own pixels for the atlas per
  §8.2.3).

## Forbidden inspirations

- Verbatim pixel-trace of any NousResearch asset. Their SVG is
  reference for the *direction* (gold/bronze coiled serpent);
  the V1 atlas is original Epistemos pixel-art rendered against
  this DNA.
- Pokemon's Ekans / Arbok (Nintendo IP).
- Specific D&D dragon / snake creature illustrations (WotC IP).
- Slytherin house imagery (Warner Bros / Bloomsbury IP).
- Apophis / Stargate symbology (MGM IP).

## Substitution policy

When S5.7 lands the canonical NousResearch landing-ritual SVG,
this atlas's V2 refinement should *visibly diverge* from the
landing-ritual snake — they're two different sprites for two
different rendering pipelines (per §8.2.3). Their visual
provenance must record that distinction explicitly.
