# Substrate Health Row Expansion Audit - 2026-05-24

Terminal: Phase 2 Terminal D' - Substrate Health Panel Row Expansion
Motion: Project / Compress / Recall (substrate state to Settings surface)

## Scope

Implemented in this slice:

- `SubstrateHealthPanel` now renders 17 health surfaces and adds a W-30 cognitive
  weight badge to every surface in the panel.
- `AnswerPacketHealthRow` now reports live `AnswerPacketEmitter.shared` metrics:
  total emitted, last-100 ring utilization, attention-mode histogram,
  interrupt-bucket histogram, and per-`claim_kind` histogram.
- `AnswerPacketEmitter` now retains a bounded last-100 packet ring and tracks
  monotonic per-claim-kind counts.
- `EmlObservatoryHealthRow` keeps its chip strip orange; it cannot visually
  promote research-only EML observability to green.
- `UasAcsHealthRow` reads ACS (Anchored Cognitive Substrate) evidence from
  `F-UAS-CopyCount` and `F-ACS-AnchorLookup` result
  artifacts and makes both gates clickable to per-gate detail.
- `CognitiveWeightClassHealthRow` shows W1/W2/W3/W4 badges even when FFI is
  unavailable, while keeping policy enforcement advisory until a real
  enforcement path is wired.
- `ACSAdmissionHealthRow` no longer shows a green substrate chip when its
  feature flag is off.

Concurrent worktree changes were observed outside this slice. This audit covers
only the files above plus this audit document.

## Phase Audit

Audit:
- Read `docs/EPISTEMOS_LIVING_INDEX_2026_05_24.md`.
- Read `docs/PHASE_2_TERMINAL_PROMPTS_2026_05_23.md` Terminal D.
- Inspected the existing Settings health rows, `AnswerPacketEmitter`, W-30
  doctrine, UAS/ACS artifacts, and unified substrate-health FFI shape.

Build:
- Added claim-kind counters to `AnswerPacketEmitter.Snapshot`.
- Wired `AnswerPacketHealthRow` to the live snapshot metrics.
- Added W-30 badge wrapping in `SubstrateHealthPanel`.
- Added artifact-backed UAS/ACS gate rows.
- Hardened EML, W-30, and ACS chip-strip color semantics.

Verify:
- Row count: 17 `surface(...)` calls in `SubstrateHealthPanel` (acceptance
  requires at least 12).
- `git diff --check`: passed.
- `rustup run stable-aarch64-apple-darwin cargo test --manifest-path
  agent_core/Cargo.toml --lib --quiet`: passed, 4004 tests.
- `xcrun swiftc -parse` on the changed Swift files: passed.
- Swift one-shot decoder probes for both UAS/ACS artifact shapes passed:
  `F-UAS-CopyCount PASS` and `F-ACS-AnchorLookup PASS`.
- Swift one-shot type probes passed for the multiline `Logger.notice` message
  and `nonisolated struct` helper types.
- Scoped long-line scan over touched files passed after hardening.
- `xcodebuild -project Epistemos.xcodeproj -scheme Epistemos -destination
  'platform=macOS' build`: blocked before Swift compile by missing local signing
  certificate for team `3BNL2669SL`.
- `xcodebuild ... CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`:
  progressed through Rust, asset build, module emission, and Swift compilation,
  then failed inside Xcode's build database with `database or disk is full`.
- Local disk audit after that failure showed `/System/Volumes/Data` at 100%
  capacity with about 1.0 GiB available; the Epistemos DerivedData folder was
  9.5 GiB.

Harden:
- EML chip remains orange even if research FFI reports reachable observatory math.
- UAS/ACS separates falsifier PASS artifacts from production runtime adapter
  status.
- W-30 W4 badges are labeled as weight class only; no Settings badge claims
  policy enforcement.
- W-30 advisory mode now reports `.partial`, not `.blocked`, because visible
  badge taxonomy is not itself a failed runtime gate.
- ACS admission substrate chip is green only when the ACS flag is on.

Report:
- Live screenshot was not captured because the app build could not complete
  locally before launch. The PR should attach the Settings -> Substrate Health
  screenshot after local disk pressure is cleared and the app can launch.

## No-Orphan Check

- Motion: Project / Compress / Recall.
- UAS: `settings/substrate-health-panel/*` surfaces existing substrate witnesses;
  no new durable substrate address space was introduced.
- Plane: Verification plane UI rows projecting substrate health into Settings.
- Residency: CurrentApp UI; artifact inputs remain in repository
  `artifacts/falsifiers/*/result.json`.
- WBO/error: read-only projection; no WBO ledger mutation. WBO status remains
  orange/blocked where no PASS artifact exists.
- Witness: `AnswerPacketEmitter.Snapshot`, unified substrate-health FFI JSON,
  `F-UAS-CopyCount` result, `F-ACS-AnchorLookup` result, and linked docs under
  `docs/falsifiers/`.
- Falsifier: every panel surface carries a falsifier doc link; UAS/ACS also
  links to per-gate result artifacts.
- Tier: Settings observability only; no production policy authority or runtime
  mutation is introduced.
- Rollback: revert the touched Swift files and this audit doc; no schema
  migration or persisted-state change.

## Seven-Law Check

- Density: no new model/runtime density claim.
- Address: rows preserve stable falsifier paths and UAS/ACS artifact identifiers.
- Active-support: 1 Hz polling starts on appear and cancels on disappear.
- Lattice-error: approximation/accounting rows stay orange unless backed by a
  PASS witness.
- Glue: scattered substrate witnesses are composed into one Settings panel surface.
- Duplex: no hard/soft page residency behavior changed.
- Witness: every meaningful status is backed by a snapshot, FFI readout,
  artifact, or falsifier doc link.
- Shadow Projection candidate: substrate state is projected to Settings with
  source coordinates and rollback path preserved.
