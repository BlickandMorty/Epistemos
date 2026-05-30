---
state: canonical_rename_patch
created_on: 2026-05-30
supersedes:
  - ACS as Anchored Cognitive Substrate
  - ACS as Admission Control System
  - ACS as ACS Admission
purpose: Restore ACS to the original Active Cold Storage meaning and stop acronym drift.
---

# ACS Active Cold Storage Rename - 2026-05-30

This patch restores the user's original acronym:

```text
ACS = Active Cold Storage
```

ACS is not the admission layer. Admission is now named SCOPE-Rex Admission,
SovereignGate, or AdmissionGate.

## Correct Flow

```text
User intent
  -> UAS resolves addresses
  -> Active Cold Storage exposes dormant candidates
  -> Active Assembly selects the waking set
  -> Eidos validates evidence
  -> SCOPE-Rex / SovereignGate admits or rejects action
  -> Runtime Router chooses MLX / local / cloud / tool / kernel
  -> RunEventLog + AnswerPacket make it visible
```

## Term Map

| Term | Correct role |
|---|---|
| UAS - Unified Address Space | Identity/address fabric. Every note, vector, KV page, adapter, model component, proof, citation, and tool event gets a stable address. |
| ACS - Active Cold Storage | Dormant-but-addressable memory/model substrate. Cold objects live on SSD/disk and active slices are pulled into RAM/UMA only when needed. |
| Active Assembly | Selected waking set for a task. It reads from ACS, VaultRecall, graph, KV pages, adapters, parameter anchors, and related substrate objects. |
| SCOPE-Rex Admission / SovereignGate | Admission/verdict layer: allow, warn, defer, quarantine, reject. Do not call this ACS. |
| Eidos | Closed-citation evidence gate. It decides whether a claim can cite retrieved evidence. |
| WBO / LatticeBudget | Error and approximation ledger. Every compression/projection pays budget. |
| L3 SSD Oracle / KV-Direct | Specific implementation track inside ACS for long-context KV/cache residency. |
| Parameter Connectome | Future indexed object family inside ACS for dormant model components, rank-one mechanisms, QK edges, anchors, adapters, and circuits. |

## Rewrite Rule

Any new architecture doc, prompt, test, UI label, or source comment must obey:

1. Use `ACS` only for `Active Cold Storage`.
2. Use `SCOPE-Rex Admission`, `SovereignGate`, or `AdmissionGate` for
   allow/warn/defer/quarantine/reject.
3. Use `Active Assembly` for the waking-set selector. Active Assembly reads
   from ACS, but is not ACS.
4. Use `L3 SSD Oracle` / `KV-Direct` for a storage implementation inside ACS,
   not as a replacement for ACS.
5. Use `UAS` as the primitive identity fabric. EML is only one primitive chart
   for elementary functions inside the broader substrate.

Older documents may still contain stale acronym usage. This rename patch wins
for future work unless current source code and tests prove a narrower local
meaning is required during migration.
