---
falsifier: F-TurboVec-RealAdapterFetchLeaseProbe
date: 2026-06-06
artifact: artifacts/falsifiers/turbovec_real_adapter_fetch_lease_probe/result.json
scope: metadata-only / T1-L1
---

# F-TurboVec-RealAdapterFetchLeaseProbe

North-star sentence: Epistemos is a local cognitive substrate where every
meaningful object has an address, plane, budget, status, and witness; MAS ships
the safe floor, Pro contains the gated/research/vault/omega ladder, and no
claim promotes without visible proof.

## Result

PASS as a metadata-only T1/L1 primary witness.

- Command:
  `Tools/falsifiers/f_turbovec_real_adapter_fetch_lease_probe.sh`
- Artifact:
  `artifacts/falsifiers/turbovec_real_adapter_fetch_lease_probe/result.json`
- Pinned upstream: `https://github.com/RyanCodrai/turbovec`
- Pinned revision: `efe29a184986cbf562a9847c2ac52a2990bfaca2`
- Fetch-lease address:
  `turbovec_real_adapter_fetch_lease_probe:50f480573a411e7160b379655938b9185d6c192d062ee485ee01acbc85cb4b68@1779040901000`
- Red fixtures rejected: 107.
- Planned download bytes: `8388608`.
- Planned unpacked bytes: `33554432`.
- Max planned file count: `2000`.
- Lease expiry: `1800` seconds.
- Former next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterSourceByteManifestProbe`:
  `turbovec_quarantine_real_adapter_source_byte_manifest_probe`.
- Former next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterSourceInspectionPolicyProbe`:
  `turbovec_quarantine_real_adapter_source_inspection_policy_probe`.
- Former next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterMotifExtractionCardProbe`:
  `turbovec_quarantine_real_adapter_motif_extraction_card_probe`.
- Current next research-to-build unit:
  `turbovec_quarantine_real_adapter_product_graph_no_contamination_probe`.
- Intermediate next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterCleanRoomAdapterPlanProbe`:
  `turbovec_quarantine_real_adapter_clean_room_adapter_plan_probe`.
- Intermediate next research-to-build unit, now landed as
  `F-TurboVec-RealAdapterExactBaselineShadowReplayProbe`:
  `turbovec_quarantine_real_adapter_exact_baseline_shadow_replay_probe`.

## What This Proves

The real TurboVec adapter branch now has a fail-closed lease contract for a
future bounded source archive fetch. The lease is pinned to the codeload URL for
revision `efe29a184986cbf562a9847c2ac52a2990bfaca2`, requires owner approval
to remain pending in this witness, disallows network fetch now, requires a later
source-byte manifest witness after any future fetch, preserves cleanup replay,
rollback, RunEventLog, AnswerPacket, compatibility fence, no-product-graph
audit, native-link block, and benchmark caveat, and keeps the target under
`.epistemos-quarantine/turbovec/efe29a184986cbf562a9847c2ac52a2990bfaca2`.

The witness rejects bad source refs, bad clone/fetch URLs, stale revisions, bad
license/commit refs, unsafe transports, absolute/traversal/duplicate/product
paths, missing or duplicated phases, owner/network shortcuts, product graph or
dependency insertion, native-link/runtime/model/index allowances, missing proof
surfaces, byte touches, hidden route/context/cloud authority, MAS/Live/T2+
promotion, live dense 70B claims, and SSD-as-RAM claims.

## What It Does Not Prove

This does not fetch or clone TurboVec, create quarantine directories, write a
source manifest, import code, add a product dependency, build an adapter, probe
native links, open index bytes, load Gemma/QAT/GGUF/MLX/LiteRT/model bytes,
choose RuntimeRouter/System G routes, advance L2 capability, or make L3
user-facing model capability green. It is not live 70B, live sparse 70B, or
product runtime proof.

## Architecture Consequence

TurboVec remains Eidos/AppColdStore rebuildable cache material and quarantine
research. The large-local-model path becomes more buildable because future
source bytes must be leased, byte-capped, cleanup-replayable, no-product-graph
audited, AnswerPacket-visible, and followed by a source-byte manifest before
any adapter source inspection, native-link dry run, compressed retrieval route,
Gemma/QAT context use, or 70B-class cold-assembly claim can cite it.
