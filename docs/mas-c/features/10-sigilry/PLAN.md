# MAS C Feature Plan - Sigilry

ID: `MAS-C-F10-SIGILRY-2026-07-08`
Codename: `SIGILRY`
Status: active throughout, release-polish checkpoint after core flows

## Intent

Make the MAS app visually coherent, native, and durable. Sigilry covers app
iconography, feature marks, status symbols, and design-system cohesion for the
native shell, June, Epdoc, Reckoner, and source/capture flows.

## Scope

- App icon and macOS asset sizes.
- Feature marks for June, Epdoc, Reckoner, Lodestar, Embercatch, Sync.
- MAS-safe status/provenance symbols.
- Native component grammar and visual QA.
- Bundled web asset visual consistency where WKWebView is used.

## Fabric Mapping

- F1 vault bus: icon/status assets may be referenced in note metadata only when
  stable and portable.
- F2 agent capability registry: symbols reflect real capability states.
- F3 MAS status/provenance: status art never fakes activity.
- F4 graph: icons aid recognition but do not create graph semantics.
- F5 provenance: design changes cite source/reference decisions.
- F6 event bus: status symbols subscribe to real state, not timers.

## Phases

1. Inventory existing assets and design docs.
2. Define native component grammar and icon/status system.
3. Produce or refine asset set.
4. Verify sizes, contrast, states, and reduced motion.
5. Capture manual screenshots across key MAS surfaces.

## Parked Or Forbidden

- No Experimental/1Code token target.
- No fake activity animation.
- No decorative-only redesign that hides broken behavior.
- No single-hue wash that makes the app feel like a reskin.

## Acceptance Evidence

- Asset inventory.
- Before/after screenshots.
- Contrast/size checks.
- State mapping to real MAS events.
- App icon asset verification.

