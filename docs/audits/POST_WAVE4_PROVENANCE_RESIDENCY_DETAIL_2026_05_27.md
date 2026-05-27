# Post-Wave-4 Provenance / Residency Detail Closeout - 2026-05-27

Status: product-floor UI detail slice.

Branch: `codex/post-wave4-provenance-residency-detail-2026-05-27`.

## Scope

This slice closes the visible detail gap called out in the Wave-4 roll-up:
users could see AnswerPacket claim kind and confidence, but the compact chat
badge did not expose the substrate proof fields now carried on the packet:

- `UasAddress`
- `AcsAnchor`
- `RuntimePlane`
- `ResidencyTier`
- residency signals

The fix keeps the UI non-blocking. `AnswerPacketBadge` remains a compact chip
strip; clicking a row opens a small popover with the packet's UAS / ACS anchor /
plane / residency detail.

## What Changed

- `Epistemos/Views/Chat/AnswerPacketBadge.swift`
  - Adds a compact substrate detail popover.
  - Shows anchored claims with UAS kind/hash, ACS anchor id/theorem, runtime
    plane, and residency tier.
  - Shows the first residency signals with verification, privacy, and gain
    values.
  - Keeps missing-packet rows blocked and non-clickable.
- `EpistemosTests/AnswerPacketBadgeTests.swift`
  - Guards substrate summary behavior.
  - Source-guards that the badge exposes UAS, ACS anchor, plane, and residency
    detail from the current fused chat surface.

No retrieval ranking, graph physics, editor path, or hot render loop changed.

## Existing Surface Check

The rest of this detail path was already live before this slice:

- `UasAcsHealthRow` reads falsifier artifacts and stays honest-orange/green
  based on witness state.
- `PlanePlacementHealthRow` summarizes State / Episodic / Assembly /
  Controller / Verification placement.
- `CognitiveDagCountsHealthRow` exposes NodeKind / EdgeKind counts without
  render-loop work.

This PR connects those substrate facts back to the chat row where users inspect
an actual answer.

## No-Orphan Check

- Motion: Project / Recall from AnswerPacket substrate fields to visible chat UI.
- UAS: UAS kind/hash appears in the popover when a claim carries an address.
- Plane: ACS anchor `RuntimePlane` is shown by display name.
- Residency: ACS anchor `ResidencyTier` and packet residency signals are shown.
- WBO/error: no green state is introduced; the badge remains a detail surface,
  not a falsifier-success claim.
- Witness: packet claims, ACS anchors, residency signals, and existing
  falsifier-backed health rows are the witnesses.
- Falsifier: existing UAS / ACS falsifiers remain the measurement authority;
  this slice adds UI/source guards only.
- Tier: product-floor visibility, not a new research claim.
- Rollback: pure UI projection; rollback is reverting the badge detail surface.

## Verification

Required gates for this slice:

- `git diff --check`
- `xcodebuild ... test -only-testing:EpistemosTests/AnswerPacketBadgeTests`
- `cargo test --manifest-path agent_core/Cargo.toml --lib --quiet`
- `xcodebuild ... build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""`
