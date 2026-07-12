# 00 — READ FIRST: Low-RAM Preparation Packet (2026-07-11)

PREPARATION ONLY — subordinate to the July 8 MAS master canon. This document does not change the active execution key or prove implementation.

## What this directory is

This directory was produced on 2026-07-11 by a single low-RAM, source-reading
and planning agent while the laptop was reserved for other RAM-intensive work.
It contains preparation packets for the three future canonical execution IDs so
that, once KEELSTONE's exact build/archive/runtime evidence chain completes in
a safe resource window, implementation can start without re-deriving
requirements, source ownership, seams, or test designs.

- Active execution key (unchanged by this work):
  `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` — status INCOMPLETE
  (evidence chain blocked at the resource preflight on 2026-07-10; swap was
  95.1% occupied; no build, archive, gate, or runtime item ran).
- Authoritative canon: `/Users/jojo/Downloads/epistemos_mas_master_canon_2026_07_08`
  (docs 00–10), plus the two Keelstone closeout documents in
  `/Users/jojo/Downloads/Epistemos/docs/plans/keelstone/`
  (`HANDOFF_OWNER_STEERS_CLOSEOUT_2026_07_10.md`,
  `KEELSTONE_EXACT_RUNTIME_EVIDENCE_2026_07_10.md`).
- Lock: `MAS-ONLY-SHIP-LOCK-2026-07-07`. Owner-intent lock:
  `OWNER-INTENT-HARDENING-LOCK-2026-07-07`.

## What this directory is NOT

- It is not implementation, hardening proof, or runtime evidence.
- It does not complete KEELSTONE, begin another canonical execution key, or
  reorder the canon build order.
- It does not modify anything under `/Users/jojo/Downloads/Epistemos` (the
  dirty `feat/goose-surface` worktree, HEAD `0c7123ba4`, was read-only during
  this pass).
- Classifications like EXISTING AND REUSABLE mean "present in current source
  text as read on 2026-07-11"; they never mean tested, compiled, or
  runtime-proven. Everything here inherits `REQUIRES RUNTIME EVIDENCE` until
  the relevant canonical phase runs its own evidence chain.

## Canonical execution IDs covered

| ID | Canon doc | Packet |
|---|---|---|
| `EPISTEMOS-MAS-KEELSTONE-RELEASE-GATE-2026-07-08` (active, incomplete) | 04 | context only, in `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` |
| `EPISTEMOS-MAS-JUNE-MINICHAT-INTEGRATOR-2026-07-08` | 05 | `JUNE_MINICHAT_IMPLEMENTATION_PACKET.md` |
| `EPISTEMOS-MAS-LUMENLENS-RECKONER-WORKSPACE-2026-07-08` | 06 | `LUMENLENS_RECKONER_IMPLEMENTATION_PACKET.md` |
| `EPISTEMOS-MAS-CAPABILITY-RING-2026-07-08` | 07 | `CAPABILITY_RING_IMPLEMENTATION_PACKET.md` |

## File inventory

1. `00_READ_FIRST_PREPARATION_ONLY.md` — this file.
2. `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` — dependency graph, the nine shared
   contracts, current source owners, duplicate-authority risk map.
3. `JUNE_MINICHAT_IMPLEMENTATION_PACKET.md` — Prompt 3 requirements traced to
   source, classification, batches, proposed tests.
4. `LUMENLENS_RECKONER_IMPLEMENTATION_PACKET.md` — Prompt 4 requirements traced
   to source, classification, batches, proposed tests.
5. `CAPABILITY_RING_IMPLEMENTATION_PACKET.md` — Prompt 5 requirements traced to
   source, provider legality, classification, batches, proposed tests.
6. `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md` — exact proposed test names,
   fixtures, assertions, and target files per batch (no code written).
7. `CONTRADICTION_AND_PROVENANCE_MAP.md` — cross-phase contradictions, stale
   docs, parked-lane residue, provenance of salvaged requirements.
8. `LOW_RAM_PREPARATION_HANDOFF.md` — per-cycle log (files inspected,
   requirements traced, contradictions, unresolved questions) and the final
   handoff summary.
9. `PREPARATION_PACKET_CORRECTION_LOG.md` — owner-adjudicated corrections
   (2026-07-11). Where it conflicts with older text in files 2–8, the
   correction log wins.

## Resource mode this was produced under

Permitted and used: file reads, `rg`, lightweight text inspection, writing to
this directory. Not run: xcodebuild, Swift/Rust compilation, tests, archives,
app launches, model loads, provider requests, Core ML, audio, package
installs, browser automation, parallel agents.

## How to consume this after KEELSTONE completes

1. Read `PREPARATION_PACKET_CORRECTION_LOG.md` first — it supersedes specific
   classifications in the other files. Then re-verify the facts marked
   `REQUIRES LOCAL VERIFICATION` (cheap `rg`/`plutil` checks) — the dirty
   worktree may have moved.
2. Follow the batch order inside each packet; batches are ordered by
   dependency, smallest first.
3. Convert the proposed tests in `TEST_FIXTURE_AND_ACCEPTANCE_MATRIX.md` into
   real tests in the named target before or alongside each batch.
4. Keep one tool registry, one approval path, one provenance ledger, one
   transcript authority — the duplicate-authority risk table in
   `CANONICAL_DEPENDENCY_AND_SEAM_MAP.md` lists exactly where a second
   authority would creep in.
