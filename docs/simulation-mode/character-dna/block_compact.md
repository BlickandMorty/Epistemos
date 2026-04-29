# Character DNA — Block (Compact variant)

> Body family: **Block** (parameterized per DOCTRINE §5.1).
> Compact aspect (1:1, ~48×48). Used by the Kimi worker, Codex
> worker, and Local Helper presets. Each preset re-skins the
> shared body via the §10.5 palette mask — there is one
> `block_compact` atlas; palette + accessory parameters dress it.

This document is human-authored Character DNA per DOCTRINE §10.2.
It is the legal-substantial-authorship contract for every Compact
Block sprite Epistemos ships. The procedural V1 atlas generator
(`Tools/asset_pipeline/procedural_atlas_v1.py`) reads this DNA
to emit pixel patterns; an artist who refines those patterns in
Aseprite under §10.3 V2 inherits this same contract.

---

## Identity

A small, sturdy pixel block. The silhouette reads as **purposeful
and approachable** — a craftsperson cube. Roughly square (~48×48)
with two short stub legs at the bottom and a flat top (no
antennae for the V1 Compact preset; `Block(Compact, Stubs, None,
Filled)` per the §5.1 parameter table).

The character carries a **prop** in front of its body in the
`tool` and `walk` animations — a wrench, scroll, magnifier,
folder, baton, or lantern. The prop is the visual cue for tool
affinity (§5.5 Category A). At rest the prop is held lightly to
the side; during `tool` it rises and articulates.

## Personality (animation direction)

| State | Personality |
| --- | --- |
| `idle` | gentle 1-pixel side-to-side sway (4 frames); tiny shoulder-shrug bob. Reads as "alert, ready". |
| `walk` | 8-frame brisk gait. Stub legs alternate; body rocks 1px each step. Brisk, not cute. |
| `think` | 6-frame head tilt; the upper third of the body lifts 1px and tilts 1px right. Reads as "considering". |
| `speak` | 4-frame mouth-region pulse (eye-region brightness modulates because Compact has no separate mouth). |
| `tool` | 6-frame prop articulation; body holds steady, prop rises + rotates 8°. |
| `spawn` | 5-frame entrance — body materialises bottom-up over 5 horizontal scanlines (no Gaussian, just stepped reveal). |
| `handoff_give` | 8-frame outstretched-arm sequence handing the scroll right-ward. |
| `handoff_receive` | 6-frame catch-and-bring-in animation. |
| `retrieve` | 6-frame "consult the folder" gesture. Body bends 1px down, prop folder opens. |
| `error` | 4-frame jagged shake — body offsets ±1px horizontal each frame. |
| `recover` | 6-frame mended stance loop — body breathes slowly. |
| `success` | 4-frame celebration — body bobs up 2px, returns. |
| `sleep` | 4-frame slow rise/fall, body 1px lower than idle. |
| `gate` | 2-frame hold pose — body slightly hunched, prop forward (asking permission). |

## Palette family

The Compact Block is a **two-tone palette**:

| Channel | Role | Notes |
| --- | --- | --- |
| **Body (B in mask)** | dominant fill | provider primary (Kimi indigo `#5B8DEF`, Codex neutral `#9C9C9C`, Local teal `#2BA59B`) |
| **Accent (G in mask)** | belt / arm bands / prop tint | provider secondary; ~30% of body pixels |
| **Eye (R in mask)** | eye cutouts / eye gleam | high-contrast against body — light cream for cool palettes, dark for warm |

The mask is shader-applied (§10.5); we do not bake a per-palette
atlas. Custom companions can pass any sRGB hex per §6.2 contrast
gate.

## Silhouette direction (original)

- Outer rectangle ~48px wide × ~48px tall (Compact 1:1).
- Bottom edge has two **stub legs**: ~6px wide × ~6px tall each,
  separated by ~10px. The stubs are integral parts of the
  silhouette; they are NOT the multi-leg notches of the Wide
  Block (those are §5.1 Wide).
- Top edge is **flat** (no antennae). This is what makes Compact
  read as "humble/approachable" rather than the Wide Block's
  scholarly-bookend feel.
- The prop hangs in front of the body, slightly right of center
  (right-handed grip). The prop sprite is a separate overlay
  layer (§5.2 layer 5) — not baked into the body atlas.
- Eyes are **filled** (overlay sprite from `overlays/eyes/`),
  in contrast with the Wide Block's negative-space cutouts.

## Allowed inspirations

- The Bauhaus square. Geometric, deliberate, chunky.
- Early-arcade pixel-art enemies (1-bit silhouette discipline).
- Tetris pieces (chunky, satisfying weight).
- Industrial robots (the no-nonsense block-with-prop archetype).

## Forbidden inspirations

- The Kimi CLI mascot (the orb / spherical Kimi character) — the
  user-supplied reference is **inspiration only**; we never
  trace pixels, we never recolor a Kimi-mascot rasterization.
  The Compact Block is a *different* silhouette family from the
  Kimi orb; cross-pollinating them would dilute both identities
  AND create legal exposure.
- Codex CLI mascot artwork.
- Tamagotchi or Bandai-pixel-pet silhouettes (Tamagotchi is a
  Bandai trademark per §10.1; we say "Companion" / "Session
  Sprite" / "Agent Pet" in user-facing copy).
- The Apple Mac SE / Macintosh-classic silhouette (looks
  superficially like a Block; legally distinct, but an
  unmistakable copy would be confusion).

## Substitution policy

If the procedural V1 atlas is replaced by an artist-refined V2
atlas, the artist works against this document. The V2 atlas's
provenance.json must record the artist, the date, the model
used (if any AI assistance was applied), and a visual-diff
report against this DNA.
