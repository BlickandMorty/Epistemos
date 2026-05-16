# B-4 NousResearch SVG Art — User Decision Research

**Status:** COMPLETE_RESEARCH_READY  
**Date:** 2026-05-16  
**Terminal E scope:** user-decision preparation only; no implementation.

## Problem Statement

The user needs to decide whether Epistemos should ship literal NousResearch/Hermes visual assets, use an Epistemos-owned fallback, commission an independent custom asset, or defer the art surface entirely.

The reconciliation gate changes the framing. The original `HERMES_BRAND_DOCTRINE_2026_05_04.md` captured a real user preference for actual NousResearch/Hermes identity, but that doctrine is now superseded for MAS V1: the Hermes Expert Mode UI overlay and brand surface were deleted on 2026-05-05, current `Epistemos/` has no Hermes/Nous SVG asset surface, and MAS final-stretch doctrine says NR brand is not a MAS-shipping blocker. The remaining B-4 decision is about future Wave H / V2.6 art, not V1 release correctness.

Current external licensing posture also matters. Nous Research's current Terms of Service say their materials, trade names, and trademarks remain owned by Nous Research and that commercial/promotional distribution of Nous Research Materials requires prior written permission. The public `NousResearch/hermes-agent` repo is MIT-licensed software; that does not grant permission to bundle the Nous logo, Hermes wordmark, or website SVG/brand assets in a commercial app. Inter and JetBrains Mono are usable as fonts under the SIL Open Font License, but they still need attribution/notice if bundled.

## Options

### Option A — Use literal NousResearch/Hermes assets after written permission

Pursue written permission or a license from Nous Research, then bundle the canonical Nous/Hermes logo, wordmark, SVG, colors, and any approved usage rules.

**Pros**
- Matches the original user correction most literally.
- Preserves visual continuity with the upstream Hermes/Nous identity.
- Gives the landing-ritual Hermes surface the strongest brand fidelity.

**Cons**
- Cannot be completed by an agent; the user or counsel must secure permission.
- Adds legal review, scope control, and App Store metadata obligations.
- Does not unblock MAS V1 because the Hermes UI overlay is already purged.
- Upstream brand guidelines could restrict placement, copy, colors, co-branding, screenshots, or paid distribution.

### Option B — Ship Epistemos-owned fallback/original Hermes art

Use original Epistemos art inspired by public-domain Hermes mythology and the already-promoted `hermes_snake.md` visual DNA: coiled serpent/caduceus direction, gold/bronze palette, no Nous logo, no copied SVG paths, no Nous wordmark. Keep Inter + JetBrains Mono if desired under OFL notice.

**Pros**
- No dependency on third-party brand permission.
- Matches Canonical Unification §4.5's explicit substitution allowance.
- Preserves the Hermes-mythology direction without reviving the deleted Hermes Expert Mode overlay.
- Can ship in MAS/V1.x or Wave H without waiting on legal.
- Gives Epistemos an owned visual asset that can evolve independently.

**Cons**
- Does not satisfy the exact "real NousResearch logo" preference unless the user later chooses Option A.
- Requires design/art work and visual QA.
- Must be visually distinct enough that it is not a traced or confusingly similar Nous asset.

### Option C — Commission independent custom art

Commission a designer/artist to create an original Hermes/caduceus/snake system with assignment or commercial-use license to Epistemos.

**Pros**
- Gives professional polish and clearer ownership than a quick internal fallback.
- Can define a full asset family: landing SVG, graph faculty sprite reference, icons, palette, and usage rules.
- Avoids copying Nous assets while still targeting the user's desired emotional direction.

**Cons**
- Requires budget, art direction, contract terms, and asset review.
- Slower than internal fallback art.
- Still needs legal/brand review to avoid confusing similarity with NousResearch marks.

### Option D — Defer B-4 entirely

Do not ship any Hermes/Nous-specific art surface until post-V1. Keep only model/runtime references such as Hermes function-calling prompt formats where technically relevant.

**Pros**
- Lowest legal and implementation risk.
- Aligns with the 2026-05-05 purge of the Hermes Expert Mode UI.
- Keeps MAS V1 focused on Epistemos-owned product surfaces.

**Cons**
- Leaves Wave H4 unresolved.
- Future Simulation/Graph Faculty work loses a strong visual reference unless Option B or C is chosen later.
- May feel like the original visual-identity correction was ignored rather than resolved.

## Canonical Sources

### `docs/fusion/HERMES_BRAND_DOCTRINE_2026_05_04.md`

- Lines 19-23: records the user's expectation that "Hermes Agent" should show the actual NousResearch brand, not generic placeholders.
- Lines 39-49: identifies the Nous Research logo, Hermes wordmark, Hermes sigil, and caduceus options; says literal Nous identity requires permission.
- Lines 59-62: recommends Inter + JetBrains Mono as free/open font choices.
- Lines 87-95: recommends a mythological caduceus as a zero-license-risk Hermes-themed mark.
- Lines 99-123: makes the licensing gate explicit and lists the three user choices: ask permission, ship Hermes-mythology/free assets, or design a distinct identity.
- Lines 179-203: places the asset/license decision as a user-decision-gated phase item.
- Lines 218-235: lists the old `HERMES-BRAND-STUB` surfaces that existed before the purge.

### `docs/fusion/CANONICAL_UNIFICATION_INVENTORY_2026_05_04.md`

- Lines 225-234: confirms canonical NousResearch SVG art was the intended reference, but explicitly allows Epistemos fallback art when licensing is unsettled.

### `docs/fusion/simulation/character-dna/hermes_snake.md`

- Lines 23-34: splits the landing-ritual SVG from the simulation-theater atlas and says the atlas must be its own redrawn original.
- Lines 88-98: allows public-domain caduceus, ouroboros, 8-bit snake direction, and NousResearch SVG as direction reference only.
- Lines 99-104: forbids verbatim pixel-trace of NousResearch assets.
- Lines 110-116: requires visual-provenance distinction between landing SVG and simulation atlas.

### `docs/HERMES_REMOVAL_HANDOFF_2026_05_05.md`

- Lines 25-39: records deletion of `Epistemos/Views/Landing/Hermes/`, `HermesBrand.swift`, `HermesShimmeringSigil.swift`, the graph Hermes glyph, and related tests.
- Lines 226-238: final-state table marks Hermes Expert Mode UI and Hermes brand surface as deleted.

### `docs/MASTER_FUSION_NO_COMPROMISE_2026_05_13.md`

- Lines 429-440: classifies Hermes as positioning, not brand, and marks the Hermes UI overlay as superseded/purged.
- Lines 465-475: UI/UX/brand table shows NousResearch SVG art plus OFL fonts collapsed to InterVariable-only current state.
- Lines 919-927: Wave H4 remains "NousResearch SVG art" and is licensing-gated.

### `docs/MAS_FINAL_STRETCH_NO_NUANCE_LOST_2026_05_14.md`

- Lines 62-68: says the NousResearch licensing decision is externally gated, MAS does not need NR brand, and the Hermes UI overlay was purged.

### `docs/SUBSTRATE_V2_FINAL_CLOSEOUT_2026_05_05.md`

- Lines 15-17: V2.6 UX/brand is not started and gated by NousResearch licensing.
- Lines 120-128: brand asset re-import remains externally gated.

### Current on-disk state

- `find Epistemos -iname '*.svg' -o -iname '*nous*' -o -iname '*caduceus*' -o -iname '*hermes*'` finds only `Epistemos/LocalAgent/HermesLocalAgentCompatibility.swift`; no active Hermes/Nous brand art assets are present.
- `Epistemos/Hermes/` does not exist in this worktree.
- `Epistemos/Resources/Fonts/Inter-Regular.ttf` and `Epistemos/Resources/Fonts/JetBrainsMono-Regular.ttf` are present.
- `docs/legal/licenses.md` lines 40-47 cover model licenses, not a NousResearch brand-asset license.

### External primary sources checked 2026-05-16

- Nous Research Terms of Service: <https://portal.nousresearch.com/terms>. Section 12.1 states Nous Research materials, trade names, and trademarks remain owned by Nous Research and require express prior written permission for commercial/promotional distribution.
- `NousResearch/hermes-agent` license: <https://github.com/NousResearch/hermes-agent/blob/main/LICENSE>. The repo's MIT license covers software/code, not Nous trademarks or brand assets.
- Inter license: <https://github.com/rsms/inter/blob/master/LICENSE.txt>. Inter is licensed under the SIL Open Font License 1.1.
- JetBrains Mono license: <https://github.com/JetBrains/JetBrainsMono/blob/master/OFL.txt>. JetBrains Mono is licensed under the SIL Open Font License 1.1.

## Code Impact Estimate

### Option A — Use literal NousResearch/Hermes assets after written permission

Estimated implementation after permission: 300-1,000 LOC plus binary assets.

Likely files/modules:
- Asset catalog or resource folder for approved SVG/PDF/PNG variants.
- A provenance/license note under `docs/legal/` naming the exact permission scope.
- `docs/legal/licenses.md` or a brand-attribution sibling document.
- Swift view(s) that consume the asset, likely under future Wave H/Graph/Simulation surfaces rather than resurrecting the deleted Hermes overlay.
- Source guard test to fail if literal Nous assets are bundled without a recorded permission artifact.

Tests/verification:
- Bundle scan proves only approved files ship.
- Legal doc names asset source, permission scope, date, and restrictions.
- Visual snapshots prove sizing and contrast.
- Source guard catches unlicensed `NousResearch`/wordmark/SVG imports.

### Option B — Ship Epistemos-owned fallback/original Hermes art

Estimated implementation: 600-1,800 LOC plus original art assets, depending on whether the first slice is just a landing SVG or also includes Graph Faculty/simulation references.

Likely files/modules:
- Original asset file(s), ideally under an Epistemos-owned brand/art path.
- Visual-provenance note explaining the asset is original Epistemos work, not copied from NousResearch.
- Optional SwiftUI/Metal/Canvas renderer if the asset becomes procedural rather than static.
- `docs/legal/licenses.md` update for Inter/JetBrains Mono OFL notices if those fonts are bundled.
- Snapshot/source-guard tests.

Tests/verification:
- `find Epistemos ...` shows no NousResearch logo/wordmark/SVG files.
- Visual diff/screenshot verifies the fallback renders at intended sizes.
- Provenance note records original asset authorship and allowed inspirations.
- Source guard forbids copied/traced Nous assets.

### Option C — Commission independent custom art

Estimated implementation after art delivery: 200-800 LOC plus contract/provenance files and assets.

Likely extra work:
- Store assignment/license paperwork outside source control or as a redacted legal note.
- Integrate exported SVG/PDF/PNG and any palette/type tokens.
- Add visual QA and source-guard tests.

Tests/verification:
- Contract/provenance artifact exists before bundling.
- Asset inventory lists designer, license/assignment, and allowed use.
- Similarity review confirms it is not a copied NousResearch asset.

### Option D — Defer B-4 entirely

Estimated implementation now: 0-200 LOC, docs/source-guard only.

Likely work:
- Mark Wave H4 as deferred until user chooses Option A, B, or C.
- Optional guard test that keeps Hermes/Nous brand assets out of MAS bundles.

Tests/verification:
- No Hermes/Nous brand asset paths are present.
- MAS docs keep B-4 in the user-decision queue.

## Recommendation

Recommend **Option B: ship Epistemos-owned fallback/original Hermes art; keep literal NousResearch assets permission-gated**.

Reasoning:
- It is the only path that respects the user's Hermes/caduceus/snake visual direction while avoiding a legal blocker.
- MAS V1 does not need NR brand, and the old Hermes overlay was deliberately purged.
- Current Nous terms make literal Nous materials and marks a written-permission issue; the public MIT code license is not a brand license.
- Canonical Unification already created the right fallback doctrine: Nous SVG can be a direction reference, but the shipped asset should be original Epistemos work unless a license is signed.
- Inter and JetBrains Mono can remain in the plan under OFL notice; describe them as OFL-permissive, not public-domain.

Recommended wording for the decision record:

> B-4 chooses Epistemos-owned original Hermes/caduceus fallback art for MAS/V1.x. Do not bundle the NousResearch logo, Hermes wordmark, or copied Nous SVG paths unless the user obtains express written permission from Nous Research and records the permission scope in the legal docs. The upstream Nous visual may remain a direction reference only; shipped art must be original and visibly distinct.

## Acceptance Criteria

If the user chooses **Option A**:
- Written NousResearch permission/license exists before any asset import.
- Permission scope covers commercial distribution inside Epistemos, App Store screenshots/marketing if applicable, and any co-branding text.
- `docs/legal/` records the permission date, scope, restrictions, and asset filenames.
- Source guard prevents literal Nous assets from entering the bundle without that record.
- Bundle scan confirms only approved assets ship.

If the user chooses **Option B**:
- No NousResearch logo, wordmark, or copied SVG path ships in the app bundle.
- The fallback art has a provenance note naming it as original Epistemos work.
- The asset follows allowed inspirations from `hermes_snake.md` and avoids the forbidden inspiration list.
- Inter and JetBrains Mono, if bundled, have OFL attribution/notice.
- Visual QA confirms the fallback works in the target Wave H / Graph Faculty surface.

If the user chooses **Option C**:
- Commission/assignment/license paperwork exists before bundling.
- Asset inventory records author, license/assignment scope, source files, and export variants.
- Similarity review confirms it is independent of NousResearch marks.

If the user chooses **Option D**:
- Wave H4 remains deferred.
- MAS source/bundle scans continue showing no Hermes/Nous brand asset surface.
- Model/runtime references to Hermes remain separated from visual brand usage.

## Decision-Ready Prompt

**B-4 NousResearch SVG art decision:** Which visual-identity route should Epistemos take?

1. **License NousResearch assets first** — pursue written permission, then bundle approved Nous/Hermes logo/wordmark/SVG assets after legal docs are recorded.
2. **Use Epistemos-owned fallback/original art** — ship an original Hermes/caduceus/snake visual, no Nous logo or copied SVG, with Inter/JetBrains OFL notices. **Recommended.**
3. **Commission independent custom art** — hire/brief a designer and bundle only after assignment/license paperwork exists.
4. **Defer B-4 entirely** — no Hermes/Nous visual art until post-V1; keep only technical/model references.

Answer with one option label and any constraints, for example: "Option 2, but make it a graph-faculty caduceus first; no landing-page Hermes hero in V1."
