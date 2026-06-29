# Plan 3 — Provenance moat (shipped code, Pass 4)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §4`. Swift-only honest-chip fix + hover-lineage moat.
> **Shipped invariant:** `VRMLabelView` must NEVER read `packet.uiLabel` — only `VRMLabel.honestLabel(for:)`.
> `Verified` is visible only when an active claim has a verifiable ACS anchor; UAS is address identity, not proof.
> Empty packets render no chip.
> `[VERIFIED-CODE]`/`[INFERRED]` tagged.

## Verified anchors
`VRMLabel` `AnswerPacket.swift:167-196`; `Claim{status,kind,uasAddress,acsAnchor}` `:278-326`; `ClaimStatus.active` `:269`;
hardcoded `uiLabel=.plausibleButUnverified` (`AnswerPacketEmitter.swift:364` stub + `:397` request). Swift `Claim` has
ACS anchors as verification evidence; `uasAddress` is stable identity metadata and cannot authorize `.verified` alone.
`VerifiedFloorChipStrip` green = `productionWired && falsifierPassed && artifactSatisfied && liveBackingSatisfied`
(`SettingsSurfaceComponents.swift`). `RustProvenanceLedgerClient.summary().claimCount` + `RustCognitiveDagClient.stats().nodeCount`
exist, `nonisolated`, return `.empty` when FFI absent, and are used by `VerifiedFloorLiveBacking`. `ChatMessage.answerPacketId`
plus `LatestAnswerPacketSink.shared.packet(for:)` are the per-turn packet bridge.

## Fix A — honest label gate [DELIVERED]
`VRMLabel.honestLabel(for packet:) -> VRMLabel?`:
- `nil` (NO CHIP) when no `.active` claims → preserves "honest by omission".
- `.verified` ONLY if ≥1 active claim whose kind ∈ {`.empirical,.mathematical,.codeInvariant`} AND
  `claim.acsAnchor` is a valid ACS verification anchor. This is the only green path.
- else `.speculative` (all speculative) / `.plausibleButUnverified` (self-witness or unanchored verifiable).
- Never invents `.blocked` (that's an upstream safety state, not claim-derivable).
**Emitter change** (`AnswerPacketEmitter.swift:351-353`, where `interruptBucket` is stamped): after stamping, if
`let honest = VRMLabel.honestLabel(for: stamped) { stamped.uiLabel = honest }` — derive from claims, don't trust the
placeholder. Empty-claims stub path needs no change (honestLabel→nil → no promotion → no chip).
**Test** `EpistemosTests/VRMLabelHonestLabelTests.swift`: empty→nil; UAS-addressed self-witness→plausible;
ACS-anchored empirical/codeInvariant→verified; speculative-even-ACS-anchored→plausible; **invariant sweep over all
`ClaimKind.allCases` × statuses asserting no `.verified` leaks without (active + ACS-anchored + verifiable-arm)**.
(`ClaimKind` is `CaseIterable :38`; `ClaimStatus` is NOT — enumerate arms by hand.)

## Fix B — tightened `VerifiedFloorChipStrip` [DELIVERED]
The existing init remains source-compatible, with opt-in real gates that AND into green:
`requiresArtifactAtPath: String? = nil` (green also requires the file to exist on disk) and
`requiresLiveBacking: VerifiedFloorLiveBacking = .none` (`.ledger` → `RustProvenanceLedgerClient.summary().claimCount > 0`;
`.dag` → `RustCognitiveDagClient.stats().nodeCount > 0`). `greenEligible = productionWired && falsifierPassed &&
artifactSatisfied && liveBackingSatisfied`. Witness label shows "no artifact"/"empty" instead of "PASS" when a declared
backing is missing, so a literal-true cannot force green on rows that declare backing. `AnswerPacketHealthRow` opts into
ledger backing with `requiresLiveBacking: .ledger`; other rows stay deliberate row-by-row adoption.

## Moat-1 — `VRMLabelView` hover-lineage card [DELIVERED]
Chip text/color from `honestLabel(for:)` ONLY; renders **nothing** when nil. Hover popover surfaces: model + tier +
verification score (`packet.residencySignals.map(\.verificationScore).max()`, `:204`) + generatedAt (newest claim
`createdAtMs`) vs acceptedAt + the **claim list** (kind/status dot + a `link` glyph for ACS verification anchors and a
`number` glyph for UAS-addressed claims). Lineage fields the
packet doesn't carry (model/tier/acceptedAt) are **explicit view inputs from `ChatMessage`** — never fabricated inside
the packet. Call site (the binding that keeps it honest):
```swift
if let id = message.answerPacketId, let packet = LatestAnswerPacketSink.shared.packet(for: id) {
    VRMLabelView(packet: packet,
                 modelLabel: message.resolvedModelLabel,
                 tierLabel: message.mode?.rawValue,
                 acceptedAt: message.createdAt)
}
```

## Moat-3 — copy verifiable lineage JSON [DELIVERED]
`VRMLineageCard` includes a "Copy lineage JSON" action that writes a deterministic `VRMLineageExport` snapshot to the
pasteboard. The export recomputes `VRMLabel.honestLabel(for:)` before encoding, then includes `schema`, `packet_id`,
`honest_label`, model/tier inputs, accepted/generated timestamps, verification score, claims, residency signals,
attention/interrupt state, and witness/mutation refs. It intentionally excludes legacy stored `ui_label` and performs
no Rust writes.

## Dependency — full retraction cascade (FLAGGED, not built now)
The `ClaimLedger` BFS cascade (`MAX_RETRACTION_WALK_DEPTH=16`) is NOT Swift-reachable: `RustProvenanceLedgerClient` is
**read-only by doctrine** (`:13-15`). The live "undo this claim + everything downstream" demo needs a **NEW Rust write
FFI** (`record_claim_json`/`retract_claim_json` in `bridge.rs`) + **owner sign-off** (CLAUDE.md canon-hardening; Phase
8.E routes writes to the Cognitive DAG, so a second write target is a canon decision). **Buildable-now substitute:** an
EventStore edit-retraction chain via `AgentNoteEditProvenance` (`:28-80`) — each agent edit is a committed
`MutationEnvelope` on the same `artifactID`; render "this was superseded by edit X" off that chain, no write FFI.

## Shipped bundle
Fix A (`AnswerPacket.swift` + `AnswerPacketEmitter.swift`) + `VRMLabelView.swift` + `VRMLabelHonestLabelTests.swift`
are shipped together. Fix B (`SettingsSurfaceComponents.swift`) + `AnswerPacketHealthRow` ledger opt-in are shipped.
Moat-3 lineage JSON copy (`VRMLineageExport`) is shipped. Rust write FFI + cascade remain flagged-pending owner sign-off.
The Settings provenance console is also shipped as a read-only GenUI projection: it initializes to
`ProvenanceConsoleSnapshot.empty`, refreshes `ProvenanceConsoleProjectionService.snapshot(limit:)` in a cancellable
utility task, and never performs EventStore/Rust projection reads in the SwiftUI init/body path.
Durable `AnswerPacketStore` persistence is append-only JSONL under Application Support, but the store treats the log as
a bounded provenance artifact: appends/compaction open the final file with `O_NOFOLLOW` and regular-file validation,
loads reject symlink/non-regular logs, and read/restore work is capped at 8 MiB before JSON decoding.
