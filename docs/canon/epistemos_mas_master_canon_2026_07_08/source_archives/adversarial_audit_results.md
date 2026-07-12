# Adversarial Audit Results

Date: 2026-07-08
Lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`

This file records the final internal audits run before packaging the master
canon ZIP. It audits the canon packet, not the live local repository.

## Audit 1 - MAS legality and release-readiness

Verdict: PASS WITH LOCAL VERIFICATION REQUIRED.

Evidence in packet:

- `08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md` contains the official Apple and provider source spine.
- App Store architecture is constrained to sandboxed, self-contained MAS build, in-process `agent_core`, native Swift/AppKit/SwiftUI, WebKit where necessary, Keychain, approval gates, and security-scoped vault access.
- Release evidence commands include Xcode/SDK version checks, build/archive/test commands, entitlement checks, privacy manifest checks, parked-lane symbol scans, and quarantine xattr scan.

Remaining local blockers:

- Current repo entitlements, privacy manifest, build settings, and archive contents must be verified locally.
- App Review notes, support/privacy URLs, StoreKit/proxy/cloud choices, and provider adapter choices still require owner/product decisions.

## Audit 2 - F1-F6 integration

Verdict: PASS WITH LOCAL VERIFICATION REQUIRED.

Evidence in packet:

- `02_MASTER_BUILD_ORDER_AND_DEPENDENCY_GRAPH.md` orders KEELSTONE before MAS June, LUMENLENS, RECKONER, and capability-ring work.
- `05_MAS_JUNE_AGENT_AND_MINICHAT.md` keeps Epdoc Assist/MiniChat under one June session, one transcript authority, one tool authority, and one provenance model.
- `06_LUMENLENS_RECKONER_WORKSPACE_PLAN.md` keeps editor truth and dataset artifacts in one workspace fabric.
- `07_CAPABILITY_RING_RESEARCH_CAPTURE_SYNC.md` maps ResearchHub, Quick Capture, Sync, PDF, Vision, Speech, and Browser features across F1-F6.

Remaining local blockers:

- The current repo must prove its actual F1-F6 event names, storage paths, UI seams, and tool registries match the canon.
- Any mismatch must update the feature doc before implementation continues.

## Audit 3 - Contradiction and buildability

Verdict: PASS WITH GUARDRAILS.

Evidence in packet:

- `source_inventory.json` inventories 18 source ZIPs and 733 extracted files.
- `source_map.json` classifies all 733 source files.
- `source_archives/contradiction_sweep_summary.md` summarizes 7718 raw contradiction hits from extracted source archives.
- `09_PARKED_PROVENANCE_AND_SUPERSESSION_LEDGER.md` resolves the actual 18 archive set and names `research1.zip` through `research4.zip` as the latest executive synthesis layer.
- Active docs retain parked-lane terms only as guardrails, forbidden lists, leak-scan commands, or supersession/provenance notes.

Remaining local blockers:

- The live repo must run the parked-lane leak scan before any MAS release claim.
- `files (5).zip` contains old code hints only; none of it can be treated as current repo truth without local verification.

## Final packaging bar

The final ZIP may be treated as a canonical planning/research packet, not as a
release-ready app proof. Release readiness still requires the commands and
manual/runtime checks in `08_MAS_LEGALITY_PRIVACY_RELEASE_EVIDENCE.md`.
