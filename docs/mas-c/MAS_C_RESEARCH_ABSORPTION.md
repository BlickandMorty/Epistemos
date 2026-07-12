# MAS C Research Absorption

ID: `MAS-C-RESEARCH-ABSORPTION-2026-07-08`

## Executive Thesis

MAS C accepts the Cursor research direction: stop trying to maintain a Pro,
Experimental, or 1Code-shaped product while preparing MAS. Build one App Store
product around native macOS quality, MAS June, in-process `agent_core`, vault
file truth, append-only provenance, and App Review-safe source/legal behavior.

## Accepted From Cursor Research

- Replace twenty overlapping operational prompts with a small set of control
  docs and five reusable prompts.
- Treat phase plans as attachments, not giant paste-to-agent prompts.
- Build order: Keelstone -> MAS June -> LumenLens -> Reckoner -> Quick Capture,
  Sync, Lodestar, and other capabilities.
- MiniChat should be a native Epdoc dock powered by MAS June and the same
  `agent_core` session, not 1Code or a second agent stack.
- Storage should hybridize: vault files as truth, append-only provenance/op-log
  as witness, GRDB/search/index layers as rebuildable derived state.
- ResearchHub source legality must be explicit before shipping any source.
- Base app pruning and release archive scans are first-class work, not cleanup.

## Corrected Or Narrowed From Cursor Research

- Goose/Hermes names in source are not automatically illegal. MAS C distinguishes
  names, in-process bridge behavior, and actual forbidden subprocess/runtime
  leakage.
- `network.server` is not automatically fatal if the product truly needs
  loopback-only in-process communication, but it must be justified or removed.
- Old storage architecture should not be restored wholesale. Useful older
  storage ideas can be rebuilt as additive derived/index/provenance layers.
- Reddit and other social feeds are not "just another source"; they need a
  licensing and review decision before any commercial App Store feature.

## Current Local Verification Facts Absorbed

- App Store entitlements include sandboxing, application group, user-selected
  file access, app-scoped bookmarks, audio input, network client, and network
  server.
- Privacy manifest currently declares required-reason APIs for file timestamps,
  system boot time, disk space, and user defaults; collected data and tracking
  arrays are empty.
- App surface compile-time guards exist for App Store versus Experimental
  surface selection.
- `JuneEpdocAssist` and `EpdocCopilotDockView` exist and should become the MAS
  MiniChat path.
- `AtomicVaultWriter` and `EditorProvenanceStore` exist and should be part of
  Keelstone/LumenLens/storage-fusion evidence.

## MAS C Non-Drift Rules

- A feature doc may mention parked lanes only in a `Parked / forbidden` section
  or as provenance.
- If a doc says "agent", it means MAS June through `agent_core`.
- If a doc says "storage truth", it means vault files.
- If a doc says "index", "database", or "cache", it must say whether it is
  rebuildable.
- If a doc says "native", it must define which part is Swift/AppKit/SwiftUI and
  which part is bundled WKWebView.
- If a doc says "done", it must point to a release-evidence check.

