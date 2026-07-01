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
plus `LatestAnswerPacketSink.shared.packet(for:)` are the per-turn packet bridge. `FalsifierArtifactsHealthRow`
shallow-enumerates a capped set of `artifacts/falsifiers/*` candidates, requires a readable bounded regular
`result.json`, reads it through a no-follow regular-file envelope, and skips symlinked falsifier directories.

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
`requiresArtifactAtPath: String? = nil` (green also requires a readable regular non-symlink file on disk) and
`requiresLiveBacking: VerifiedFloorLiveBacking = .none` (`.ledger` → `RustProvenanceLedgerClient.summary().claimCount > 0`;
`.dag` → `RustCognitiveDagClient.stats().nodeCount > 0`). `greenEligible = productionWired && falsifierPassed &&
artifactSatisfied && liveBackingSatisfied`. Witness label shows "no artifact"/"empty" instead of "PASS" when a declared
backing is missing, so a literal-true cannot force green on rows that declare backing. `AnswerPacketHealthRow` opts into
ledger backing with `requiresLiveBacking: .ledger`; `FalsifierArtifactsHealthRow` caps artifact candidate scanning and
bounds/no-follows each `result.json` artifact before parsing; verified-floor pill tints come from `UIState.theme`
semantic success/warning/error/muted tokens instead of raw SwiftUI colors; other rows stay deliberate row-by-row adoption.

## Moat-1 — `VRMLabelView` hover-lineage card [DELIVERED]
Chip text/state from `honestLabel(for:)` ONLY; renders **nothing** when nil. The visible chip and copy-lineage action
use shared `ToolbarCapsuleButton` chrome, claim status dots and muted metadata derive from `UIState.theme`, and the
lineage card uses spacing rather than hard `Divider()` rules. Hover popover surfaces: model + tier +
verification score (`packet.residencySignals.map(\.verificationScore).max()`, `:204`) + generatedAt (newest claim
`createdAtMs`) vs acceptedAt + the **claim list** (kind/status dot + a `link` glyph for ACS verification anchors and a
`number` glyph for UAS-addressed claims). The hover-lineage card bounds runtime-fed metadata, claim text, and displayed
claim count before SwiftUI render, bounds strings before trimming, and keeps ellipsis inside configured caps; the
copyable lineage JSON remains full-fidelity. Lineage fields the
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

## Moat-2 substitute — EventStore edit supersession chain [DELIVERED]
`ProvenanceConsoleProjectionService` now derives an `AgentEditSuperseded` GenUI trace from committed
`MutationEnvelope` rows: it reads bounded recent envelopes from `EventStore.recentMutationEnvelopes(limit:)`, filters
committed agent `artifactUpdate` edits, groups by touched artifact, and renders "this edit was superseded by edit X"
for consecutive mutations on the same artifact. The projection is read-only, EventStore-derived, bounded at the service
edge, and performs no ClaimLedger writes.

## Dependency — full retraction cascade (FLAGGED, not built now)
The `ClaimLedger` BFS cascade (`MAX_RETRACTION_WALK_DEPTH=16`) is NOT Swift-reachable: `RustProvenanceLedgerClient` is
**read-only by doctrine** (`:13-15`). The live "undo this claim + everything downstream" demo needs a **NEW Rust write
FFI** (`record_claim_json`/`retract_claim_json` in `bridge.rs`) + **owner sign-off** (CLAUDE.md canon-hardening; Phase
8.E routes writes to the Cognitive DAG, so a second write target is a canon decision). The buildable-now substitute is
delivered via the EventStore edit supersession chain above; the true ClaimLedger cascade remains blocked on explicit
owner approval for a new write FFI.

## Shipped bundle
Fix A (`AnswerPacket.swift` + `AnswerPacketEmitter.swift`) + `VRMLabelView.swift` + `VRMLabelHonestLabelTests.swift`
are shipped together. Fix B (`SettingsSurfaceComponents.swift`) + `AnswerPacketHealthRow` ledger opt-in are shipped.
Moat-2 EventStore edit supersession and Moat-3 lineage JSON copy (`VRMLineageExport`) are shipped. Rust write FFI +
ClaimLedger cascade remain flagged-pending owner sign-off.
The Settings provenance console is also shipped as a read-only GenUI projection: it initializes to
`ProvenanceConsoleSnapshot.empty`, refreshes `ProvenanceConsoleProjectionService.snapshot(limit:)` in a cancellable
utility task, clamps projection reads at the service boundary, caps untrusted model/tool/relation display strings before
they reach GenUI rows, includes the EventStore-derived `AgentEditSuperseded` trace, and never performs EventStore/Rust
projection reads in the SwiftUI init/body path.
Durable `AnswerPacketStore` persistence is append-only JSONL under Application Support, but the store treats the log as
a bounded provenance artifact: appends reject encoded packets or projected post-append logs over 8 MiB after opening
the final file with `O_NOFOLLOW` plus `fstat`, while compaction reads/writes and load/restore reads use the same
regular-file validation; loads reject symlink/non-regular logs, and read/restore work is capped at 8 MiB before JSON
decoding.
