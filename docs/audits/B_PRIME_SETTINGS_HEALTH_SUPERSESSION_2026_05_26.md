# B-Prime Settings Health Supersession - 2026-05-26

Status: recovered one live metric; retired stale health-chip rewrites.

Source: `stash@{0}` (`b-prime-uncommitted-followup-2026-05-26`) and draft
preservation PR #82.

Recovery rule: no stash was popped, dropped, checked out, or bulk-applied. The
stash was inspected with `git diff HEAD stash@{0}` and only the durable missing
metric was ported.

## Recovered

- `Epistemos/Views/Settings/AnswerPacketHealthRow.swift` now renders the
  existing `AnswerPacketEmitter.Snapshot.claimKindCounts` histogram as
  `By claim_kind`.
- The audit ring row now reports last-100 utilization explicitly, matching the
  B-prime intent without changing the stricter verified-floor chip API.

## Retired As Superseded Or Unsafe

The remaining Settings health row hunks in `stash@{0}` were not applied because
they predate the current verified-floor chip contract. Raw application would:

- replace `productionWired + falsifierPassed + falsifier + stillStub` evidence
  with weaker tint-only chips;
- remove the `FalsifierArtifactsHealthRow` from `SubstrateHealthPanel`;
- remove the Runtime Lanes section and Runtime Router health row;
- turn some rows green from substrate reachability alone instead of a primary
  PASS witness;
- discard current source guards and health-row tests that landed after the
  stash was created.

Current main keeps the stronger truth-floor surface. The only missing visible
health nuance from this stash was the AnswerPacket claim-kind histogram, now
recovered.

## Verification Target

- `EpistemosTests/AnswerPacketEmitterTests`
- `EpistemosTests/SettingsTruthFloorTests`
- `EpistemosTests/SubstrateHealthPanelTests`
