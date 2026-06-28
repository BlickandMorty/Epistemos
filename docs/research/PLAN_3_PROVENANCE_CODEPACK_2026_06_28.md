# Plan 3 — Provenance moat (clone-ready code, Pass 3)

> Companion to `PLAN_3_CAPABILITIES_2026_06_28.md §4`. Swift-only honest-chip fix + hover-lineage moat.
> **★ SHIP RULE: Fix A + Moat-1 land in the SAME commit.** `VRMLabelView` must NEVER read `packet.uiLabel` — only
> `VRMLabel.honestLabel(for:)`. Shipping the view without the gate re-introduces the "Verified from a hardcoded label"
> bug the deleted renderer avoided by omission. `[VERIFIED-CODE]`/`[INFERRED]` tagged.

## Verified anchors
`VRMLabel` `AnswerPacket.swift:167-196`; `Claim{status,kind,uasAddress,acsAnchor}` `:278-326`; `ClaimStatus.active` `:269`;
hardcoded `uiLabel=.plausibleButUnverified` (`AnswerPacketEmitter.swift:364` stub + `:397` request). Swift `Claim` has
NO evidence-link field — use `uasAddress`/`acsAnchor` presence as "evidence chain" `[INFERRED — confirm vs ledger.rs]`.
`VerifiedFloorChipStrip` green = `productionWired && falsifierPassed`, both caller literals (`SettingsSurfaceComponents.swift:297-319`,
19 call sites). `RustProvenanceLedgerClient.summary().claimCount` (read-only `:23,112`) + `RustCognitiveDagClient.stats().nodeCount`
(`:30,129`) exist, `nonisolated`, return `.empty` when FFI absent. `ChatMessage.answerPacketId` `ChatTypes.swift:307`;
`LatestAnswerPacketSink.shared.packet(for:)` `:103`.

## Fix A — honest label gate (`AnswerPacket.swift`, extension after `:196`)
`VRMLabel.honestLabel(for packet:) -> VRMLabel?`:
- `nil` (NO CHIP) when no `.active` claims → preserves "honest by omission".
- `.verified` ONLY if ≥1 active claim whose kind ∈ {`.empirical,.mathematical,.codeInvariant`} AND
  `claim.uasAddress != nil || claim.acsAnchor != nil` (the evidence chain). This is the only green path.
- else `.speculative` (all speculative) / `.plausibleButUnverified` (self-witness or unanchored verifiable).
- Never invents `.blocked` (that's an upstream safety state, not claim-derivable).
**Emitter change** (`AnswerPacketEmitter.swift:351-353`, where `interruptBucket` is stamped): after stamping, if
`let honest = VRMLabel.honestLabel(for: stamped) { stamped.uiLabel = honest }` — derive from claims, don't trust the
placeholder. Empty-claims stub path needs no change (honestLabel→nil → no promotion → no chip).
**Test** `EpistemosTests/VRMLabelHonestLabelTests.swift`: empty→nil; self-witness-empirical-without-anchor→plausible;
anchored empirical/codeInvariant→verified; speculative-even-anchored→plausible; **invariant sweep over all
`ClaimKind.allCases` × statuses asserting no `.verified` leaks without (active + anchored + verifiable-arm)**.
(`ClaimKind` is `CaseIterable :38`; `ClaimStatus` is NOT — enumerate arms by hand.)

## Fix B — tighten `VerifiedFloorChipStrip` (additive, source-compatible)
Keep the existing init (19 rows compile unchanged) + add opt-in real gates that AND into green:
`var requiresArtifactAtPath: String? = nil` (green also requires the file to exist on disk) and
`var requiresLiveBacking: LiveBacking = .none` (`.ledger` → `RustProvenanceLedgerClient.summary().claimCount > 0`;
`.dag` → `RustCognitiveDagClient.stats().nodeCount > 0`). `greenEligible = productionWired && falsifierPassed &&
artifactSatisfied && liveBackingSatisfied`. Witness label shows "no artifact"/"empty" instead of "PASS" when a declared
backing is missing — so a literal-true can no longer force green. Provenance rows opt in
(`requiresLiveBacking: .ledger`); the other 17 default to `.none`. Adopt per-row deliberately, not blanket.

## Moat-1 — `VRMLabelView` hover-lineage card (NEW `Epistemos/Views/Provenance/VRMLabelView.swift`)
Chip text/color from `honestLabel(for:)` ONLY; renders **nothing** when nil. Hover popover surfaces: model + tier +
verification score (`packet.residencySignals.map(\.verificationScore).max()`, `:204`) + generatedAt (newest claim
`createdAtMs`) vs acceptedAt + the **claim list** (kind/status dot + a `link` glyph when anchored). Lineage fields the
packet doesn't carry (model/tier/acceptedAt) are **explicit view inputs from `ChatMessage`** — never fabricated inside
the packet. Call site (the binding that keeps it honest):
```swift
if let id = message.answerPacketId, let packet = LatestAnswerPacketSink.shared.packet(for: id) {
    VRMLabelView(packet: packet, modelLabel: message.modelDisplayName,
                 tierLabel: message.capabilityTier, acceptedAt: message.timestamp)
}
```
`[INFERRED]` confirm `message.modelDisplayName/.capabilityTier/.timestamp` accessor names at the call site.

## Dependency — full retraction cascade (FLAGGED, not built now)
The `ClaimLedger` BFS cascade (`MAX_RETRACTION_WALK_DEPTH=16`) is NOT Swift-reachable: `RustProvenanceLedgerClient` is
**read-only by doctrine** (`:13-15`). The live "undo this claim + everything downstream" demo needs a **NEW Rust write
FFI** (`record_claim_json`/`retract_claim_json` in `bridge.rs`) + **owner sign-off** (CLAUDE.md canon-hardening; Phase
8.E routes writes to the Cognitive DAG, so a second write target is a canon decision). **Buildable-now substitute:** an
EventStore edit-retraction chain via `AgentNoteEditProvenance` (`:28-80`) — each agent edit is a committed
`MutationEnvelope` on the same `artifactID`; render "this was superseded by edit X" off that chain, no write FFI.

## Single-commit bundle
Fix A (`AnswerPacket.swift` + `AnswerPacketEmitter.swift`) + `VRMLabelView.swift` + `VRMLabelHonestLabelTests.swift`.
Separately: Fix B (`SettingsSurfaceComponents.swift`) + per-row opt-in. Rust write FFI + cascade = flagged-pending sign-off.
