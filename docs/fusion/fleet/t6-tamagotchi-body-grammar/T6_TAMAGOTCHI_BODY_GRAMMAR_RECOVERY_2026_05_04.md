# T6 Tamagotchi Body Grammar Recovery — 2026-05-04

## Status

Canonical user correction captured during the Hermes recovery slice.

## User correction

The Companion Farm is not supposed to end at SF Symbols, generic orbs, or a
static grid. The intended surface is a set of small Tamagotchi-like companion
creatures with a simple styleable avatar grammar. They should live on the
landing page, be able to wander idly/randomly, and later appear in the graph
surface as companion presences.

## Current code truth

- `Epistemos/Views/Landing/Farm/CompanionView.swift` documents that
  `bodyKind` should determine "silhouette + animation vocabulary", but the
  implementation still renders `Image(systemName: entry.bodyKind.systemImageName)`.
- `Epistemos/Views/Landing/Farm/LandingFarmView.swift` mounts companions in a
  roster grid only; it does not yet provide a roaming/walking layer.
- `Epistemos/Views/Graph/` has no companion-presence layer yet.

## Donor research truth

- `docs/fusion/jordan's research/kimis deep research/SIMULATION_MODE_V16_SUMMARY.md`
  reports Slice 3 shipped an "Orb avatar with TimelineView breathing."
- The same summary lists the next asset slice as replacing orb shapes with
  custom `MeshGradient` / `Shader` avatars.
- `/Users/jojo/Downloads/kimis deep research/epistenos/swift/EpistenosKit/Sources/Views/Landing/CompanionView.swift`
  contains only orb/shard/pulse shapes, so it is donor scaffolding, not the
  final canonical avatar grammar.

## Canonical target

1. Create a styleable companion avatar grammar, preferably SwiftUI Canvas first
   and SVG/exportable path data second, with body families such as Block, Sage,
   Orb, and Hermes Snake.
2. Replace `CompanionBodyKind.systemImageName` rendering with native drawn
   silhouettes and animation vocabulary.
3. Add a deterministic roaming layer on Landing: seeded idle walks, bounded
   paths, reduce-motion fallback, and no per-frame allocations.
4. Add a graph companion-presence layer after the landing layer stabilizes:
   companions can orbit, inspect, or idle near relevant graph nodes without
   touching graph physics/render internals directly.
5. Preserve asset optionality: if the user's own avatar/SVG assets are found,
   import them as source assets; otherwise ship the Canvas grammar and keep
   SVG export/import as a follow-up.

## First safe implementation slice

Create a new `CompanionAvatarGlyph.swift` / `CompanionAvatarGrammar.swift` under
`Epistemos/Views/Landing/Farm/` that draws the four body families in Canvas.
Then migrate `CompanionView.bodyLayer` from SF Symbol images to the grammar.
Do not touch `MetalGraphView.swift`, `HologramController.swift`, or graph
physics internals in the first slice.

## Verification

- `rg 'systemImageName' Epistemos/Views/Landing/Farm/CompanionView.swift`
  should return zero after the avatar-grammar slice.
- Reduce-motion mode should render static companions.
- Normal mode should animate via `TimelineView`, not `repeatForever`.
- Landing roaming must be deterministic from companion identity seed.

## Usefulness

+1 — prevents the Simulation/T6 surface from calcifying as generic symbols or
orbs and gives the next agent the exact canonical correction to build from.
