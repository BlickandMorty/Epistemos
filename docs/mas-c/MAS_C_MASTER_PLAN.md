# MAS C Master Plan

ID: `MAS-C-MASTER-PLAN-2026-07-08`

## Product Spine

Epistemos MAS C ships one App Store app:

1. A hard native macOS shell.
2. A security-scoped vault.
3. MAS June as the agent surface.
4. In-process `agent_core` as the tool/event/provenance authority.
5. LumenLens/Epdoc as the writing and evidence workspace.
6. Reckoner as vault-native datasets and calculation.
7. Keelstone release gates proving the MAS archive is clean.

## Build Order

1. `01-keelstone`: vault safety, release safety, leak gates.
2. `11-release-pruning`: remove or quarantine parked lanes from the MAS target.
3. `02-mas-june`: MAS June, bridge naming, cloud/local routing gates.
4. `05-epdoc-assist`: native MiniChat dock using the MAS June session.
5. `03-lumenlens`: Epdoc editor, suggestions, provenance, notebook seams.
6. `12-storage-fusion`: harden storage truth, op-log, derived indexes.
7. `04-reckoner`: datasets, IronCalc authority, Univer render-only surface.
8. `06-embercatch`: quick capture and voice capture into the vault.
9. `08-sync`: iCloud/sync durability and conflict surfaces.
10. `07-lodestar`: ResearchHub with legal source matrix.
11. `09-capabilities`: PDF, browser, voice, skills, safe tool surfaces.
12. `10-sigilry`: iconography, design system, status art, and visual coherence.

## Fabric Mapping

Every feature maps to the shared fabric:

- F1 vault bus: what files/artifacts it reads and writes.
- F2 agent capability registry: how MAS June invokes it.
- F3 MAS status/provenance: what honest activity is shown.
- F4 knowledge graph: what nodes and edges are created.
- F5 provenance and citation: what ledger entries are created.
- F6 state/event bus: what events are published or consumed.

## Storage Position

MAS C keeps the current file-truth architecture and strengthens it. The target is
not a brittle old database rollback. The best storage version is:

- Vault files and user-visible artifacts as truth.
- Append-only op-log/provenance journal as durable witness.
- GRDB/Search/graph indexes as derived and rebuildable.
- Optional proprietary storage layer only as an acceleration, recovery, or
  high-integrity witness layer that can always export/reconstruct vault truth.

## Native UI Position

MAS C should prefer real native macOS structure for the shell:

- AppKit/SwiftUI for window shell, sidebar, docks, toolbar, file pickers,
  permissions, status, popovers, conflict UI, and panels.
- Bundled WKWebView for rich editor/June/research/data surfaces only when it is
  the best implementation host and can be made local, fast, and reviewable.
- No web reskin should be accepted as a "new stack" unless component ownership,
  route structure, behavior, and interaction grammar actually changed.

## Phase Exit Rule

A phase can move forward only after:

- Its plan and build prompt agree.
- It has no active contradiction with `MAS_C_CONTROL.md`.
- Its F1-F6 mapping is filled.
- Source guards or tests cover the risk it introduced.
- Manual/runtime evidence exists for UI, vault, sync, or source-ingest behavior.
- `MAS_C_RELEASE_EVIDENCE_GATE.md` names the release check that will catch drift.

