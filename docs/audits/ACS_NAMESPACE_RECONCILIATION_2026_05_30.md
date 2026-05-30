---
state: namespace_reconciliation
created_on: 2026-05-30
supersedes:
  - docs/audits/ACS_ACTIVE_COLD_STORAGE_RENAME_2026_05_30.md
purpose: Stop ACS acronym drift without erasing current AcsAnchor/Kuramoto source truth.
---

# ACS Namespace Reconciliation - 2026-05-30

This correction replaces the temporary active-cold-storage acronym patch.
That patch fixed one collision but created another one with current code and
older canon. The stable rule is:

```text
Do not abbreviate Active Cold Storage as ACS.
Use ColdStore or Cold Residency Layer for dormant residency.
Reserve ACS for existing AcsAnchor / Anchored Cognitive Substrate / Kuramoto
research contexts until those source names are deliberately migrated.
```

## Canonical Names

| Name | Role | Notes |
|---|---|---|
| UAS | Unified Address Space: identity/address fabric for notes, claims, vectors, KV pages, model components, proofs, citations, and tool events. | Primitive identity layer. |
| AcsAnchor / Anchored Cognitive Substrate | Existing coordinate/provenance layer carried by UAS objects. | Current source uses `AcsAnchor`, `AcsAnchorRegistry`, and `F-ACS-AnchorLookup`; do not pretend this code means cold storage. |
| KuramotoSync / ResonanceSync | Research-tier phase/coherence candidate for coordinating firing subsets. | Legacy phrases include the old ACS/Kuramoto wording and `Kuramoto cellular resonance`; use the new names for forward work. |
| ColdStore / Cold Residency Layer | Dormant-but-addressable memory/model substrate. Cold objects may live on SSD/disk/mmap and active slices are pulled into RAM/UMA only when selected. | This is the user's Active Cold Storage idea. Do not abbreviate it as ACS. |
| ResidencyGovernor | Policy that decides leases, tiers, residency plans, copy-count limits, page/mmap safety, eviction, defer, or quarantine. | Works with ColdStore; not the same as AcsAnchor. |
| ActiveAssembly | Waking-set selector for a task. It reads from ColdStore, VaultRecall, graph, KV pages, adapters, parameter anchors, tools, and kernels. | Do not call this ACS. |
| SCOPE-Rex Admission / SovereignGate | Admission/verdict layer: allow, warn, defer, quarantine, reject. | Existing `acs_admission` source paths are migration debt and should not set new naming. |
| Eidos | Evidence gate and closed-citation contract. | Gathers/validates retrieved evidence; SCOPE-Rex/SovereignGate decide action validity. |
| KV-Direct / L3 SSD Oracle | Specific ColdStore implementation track for long-context KV/cache residency. | Not the whole ColdStore layer. |

## Correct Product Flow

```text
User intent
  -> CognitivePacket / MissionPacket forms the task
  -> OAS/UAS resolves what exists and where it lives
  -> ColdStore / ResidencyGovernor surfaces cold candidates without waking everything
  -> ActiveAssembly selects the minimal waking set
  -> Eidos pre-validates candidate evidence and missing context
  -> SCOPE-Rex / SovereignGate admits the proposed mission and route
  -> Runtime Router chooses local model / MLX / Apple Intelligence / tool / kernel
  -> Executor runs under policy
  -> Eidos post-validates output, citations, and tool/mutation claims
  -> SCOPE-Rex / SovereignGate admits or rejects user-impacting mutations
  -> RunEventLog records the full trace
  -> AnswerPacket makes result, evidence, uncertainty, and mode visible
```

Short doctrine:

```text
Intent -> Address -> Awaken -> Assemble -> Verify -> Govern -> Execute -> Verify -> Witness
```

SCOPE-Rex/SovereignGate is continuous mission governance, not only a late
approval step. It must gate proposed missions, provider routes, cloud access,
external tools, shell actions, file reads/writes, memory updates, and durable
mutations. Eidos also appears twice: before execution to validate the evidence
packet, and after execution to check that the output or mutation honestly
matches retrieved evidence and admitted scope.

## Rewrite Rules

1. New docs and UI should use `ColdStore` or `Cold Residency Layer` for Active
   Cold Storage.
2. New docs and UI should not say `ACS` when they mean cold storage,
   residency, mmap/SSD spill, KV-Direct, or dormant model components.
3. Keep `AcsAnchor` as-is in code until there is an intentional code migration;
   it means the existing anchored coordinate/provenance object.
4. Treat old ACS/Kuramoto wording as `KuramotoSync` / `ResonanceSync`, a
   research/candidate resonance mechanism under ActiveAssembly, not as the
   product residency layer.
5. Use `SCOPE-Rex Admission`, `SovereignGate`, or `AdmissionGate` for
   allow/warn/defer/quarantine/reject behavior. Existing `acs_admission` module
   names are transitional source debt.
6. UAS remains the primitive identity fabric. EML is one elementary-function
   chart inside the broader substrate.
